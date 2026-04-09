import Foundation

/// Concrete implementation of the AIAgent protocol.
/// Supports OpenAI, Anthropic, Google Gemini, and Ollama.
/// On iOS 17+ / macOS 14+, also supports local persistence via SwiftData.
public actor AIAgentImplementation: AIAgent {
    public let configuration: AIConfiguration

    private let openAIClient: OpenAIClient?
    private let anthropicClient: AnthropicClient?
    private let geminiClient: GeminiClient?

    /// Type-erased storage for HistoryManager to avoid placing a @available constraint
    /// on a stored property. Accessed via the computed property `historyManager`.
    private let _historyManager: Any?

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
    private var historyManager: HistoryManager? { _historyManager as? HistoryManager }

    // MARK: - Designated Initializers

    /// Initializes the agent without local persistence
    public init(configuration: AIConfiguration) throws {
        try configuration.validate()
        self.configuration = configuration
        self._historyManager = nil
        let clients = Self.buildClients(configuration: configuration)
        self.openAIClient = clients.openAI
        self.anthropicClient = clients.anthropic
        self.geminiClient = clients.gemini
    }

    /// Initializes the agent with local persistence via SwiftData (iOS 17+ / macOS 14+)
    @available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
    public init(configuration: AIConfiguration, historyManager: HistoryManager) throws {
        try configuration.validate()
        self.configuration = configuration
        self._historyManager = historyManager
        let clients = Self.buildClients(configuration: configuration)
        self.openAIClient = clients.openAI
        self.anthropicClient = clients.anthropic
        self.geminiClient = clients.gemini
    }

    // MARK: - AIAgent Protocol

    public func send(messages: [AIMessage]) async throws -> AIMessage {
        try TokenEstimator.validate(
            messages: messages,
            model: configuration.model,
            maxResponseTokens: configuration.maxResponseTokens
        )

        let response: AIMessage

        switch configuration.model.provider {
        case .openai, .ollama:
            guard let client = openAIClient else {
                throw AIError.invalidContext("OpenAI client not initialized")
            }
            response = try await client.sendCompletion(messages: messages)

        case .anthropic:
            guard let client = anthropicClient else {
                throw AIError.invalidContext("Anthropic client not initialized")
            }
            response = try await client.sendCompletion(messages: messages)

        case .gemini:
            guard let client = geminiClient else {
                throw AIError.invalidContext("Gemini client not initialized")
            }
            response = try await client.sendCompletion(messages: messages)
        }

        // Persist to history when a manager is configured (iOS 17+ only)
        if #available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *) {
            if let manager = historyManager {
                try? await manager.saveConversation(
                    messages: messages,
                    response: response,
                    modelName: configuration.model.name
                )
            }
        }

        return response
    }

    /// Feature 4: Override the JSON hook to enable native JSON mode on OpenAI and Gemini
    public func sendForJSON(messages: [AIMessage]) async throws -> AIMessage {
        try TokenEstimator.validate(
            messages: messages,
            model: configuration.model,
            maxResponseTokens: configuration.maxResponseTokens
        )

        switch configuration.model.provider {
        case .openai, .ollama:
            guard let client = openAIClient else {
                throw AIError.invalidContext("OpenAI client not initialized")
            }
            return try await client.sendCompletionJSON(messages: messages)

        case .gemini:
            guard let client = geminiClient else {
                throw AIError.invalidContext("Gemini client not initialized")
            }
            return try await client.sendCompletionJSON(messages: messages)

        case .anthropic:
            // Anthropic has no native JSON mode — rely on prompt injection from the protocol default
            guard let client = anthropicClient else {
                throw AIError.invalidContext("Anthropic client not initialized")
            }
            return try await client.sendCompletion(messages: messages)
        }
    }

    public func send(messages: [AIMessage], tools: [AITool]) async throws -> AIMessageWithTools {
        try TokenEstimator.validate(
            messages: messages,
            model: configuration.model,
            maxResponseTokens: configuration.maxResponseTokens
        )

        switch configuration.model.provider {
        case .openai, .ollama:
            guard let client = openAIClient else {
                throw AIError.invalidContext("OpenAI client not initialized")
            }
            return try await client.sendCompletionWithTools(messages: messages, tools: tools)

        case .anthropic:
            guard let client = anthropicClient else {
                throw AIError.invalidContext("Anthropic client not initialized")
            }
            return try await client.sendCompletionWithTools(messages: messages, tools: tools)

        case .gemini:
            guard let client = geminiClient else {
                throw AIError.invalidContext("Gemini client not initialized")
            }
            return try await client.sendCompletionWithTools(messages: messages, tools: tools)
        }
    }

    public func send(messages: [AIMessage], toolResults: [AIToolResult]) async throws -> AIMessageWithTools {
        let toolResultMessages: [AIMessage] = toolResults.map { result in
            AIMessage(role: .tool, content: result.content, metadata: ["tool_call_id": result.toolCallId])
        }
        let fullMessages = messages + toolResultMessages

        try TokenEstimator.validate(
            messages: fullMessages,
            model: configuration.model,
            maxResponseTokens: configuration.maxResponseTokens
        )

        let response = try await send(messages: fullMessages)
        return AIMessageWithTools(message: response)
    }

    public func stream(messages: [AIMessage]) -> AsyncThrowingStream<String, Error> {
        guard configuration.model.supportsStreaming else {
            return AsyncThrowingStream { $0.finish(throwing: AIError.streamingError("Model does not support streaming")) }
        }

        do {
            try TokenEstimator.validate(
                messages: messages,
                model: configuration.model,
                maxResponseTokens: configuration.maxResponseTokens
            )
        } catch {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }

        switch configuration.model.provider {
        case .openai, .ollama:
            guard let client = openAIClient else {
                return AsyncThrowingStream { $0.finish(throwing: AIError.invalidContext("OpenAI client not initialized")) }
            }
            return client.streamCompletion(messages: messages)

        case .anthropic:
            guard let client = anthropicClient else {
                return AsyncThrowingStream { $0.finish(throwing: AIError.invalidContext("Anthropic client not initialized")) }
            }
            return client.streamCompletion(messages: messages)

        case .gemini:
            guard let client = geminiClient else {
                return AsyncThrowingStream { $0.finish(throwing: AIError.invalidContext("Gemini client not initialized")) }
            }
            return client.streamCompletion(messages: messages)
        }
    }

    // MARK: - Local Persistence (iOS 17+ / macOS 14+)

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
    public func loadPreviousContext(limit: Int = 20) async throws -> [AIMessage] {
        guard let manager = historyManager else { return [] }
        return try await manager.loadPreviousContext(limit: limit)
    }
}

// MARK: - Private Helpers

private extension AIAgentImplementation {
    struct Clients {
        let openAI: OpenAIClient?
        let anthropic: AnthropicClient?
        let gemini: GeminiClient?
    }

    static func buildClients(configuration: AIConfiguration) -> Clients {
        switch configuration.model.provider {
        case .openai, .ollama:
            // Ollama uses the OpenAI-compatible endpoint — same client, different base URL
            return Clients(openAI: OpenAIClient(configuration: configuration), anthropic: nil, gemini: nil)
        case .anthropic:
            return Clients(openAI: nil, anthropic: AnthropicClient(configuration: configuration), gemini: nil)
        case .gemini:
            return Clients(openAI: nil, anthropic: nil, gemini: GeminiClient(configuration: configuration))
        }
    }
}

// MARK: - Convenience Initializers

public extension AIAgentImplementation {

    // MARK: OpenAI

    static func gpt4(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .gpt4, apiKey: apiKey))
    }

    static func gpt4Turbo(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .gpt4Turbo, apiKey: apiKey))
    }

    static func gpt35Turbo(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .gpt35Turbo, apiKey: apiKey))
    }

    static func gpt4o(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .gpt4o, apiKey: apiKey))
    }

    static func gpt4oMini(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .gpt4oMini, apiKey: apiKey))
    }

    static func gpt41(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .gpt41, apiKey: apiKey))
    }

    static func gpt41Mini(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .gpt41Mini, apiKey: apiKey))
    }

    // MARK: Anthropic — Claude 3

    static func claude3Haiku(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .claude3Haiku, apiKey: apiKey))
    }

    static func claude3Sonnet(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .claude3Sonnet, apiKey: apiKey))
    }

    static func claude3Opus(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .claude3Opus, apiKey: apiKey))
    }

    // MARK: Anthropic — Claude 3.5 / 3.7

    static func claude35Haiku(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .claude35Haiku, apiKey: apiKey))
    }

    static func claude35Sonnet(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .claude35Sonnet, apiKey: apiKey))
    }

    static func claude37Sonnet(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .claude37Sonnet, apiKey: apiKey))
    }

    // MARK: Anthropic — Claude 4

    static func claudeHaiku45(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .claudeHaiku45, apiKey: apiKey))
    }

    static func claudeSonnet46(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .claudeSonnet46, apiKey: apiKey))
    }

    static func claudeOpus46(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .claudeOpus46, apiKey: apiKey))
    }

    // MARK: Google Gemini

    static func gemini20Flash(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .gemini20Flash, apiKey: apiKey))
    }

    static func gemini20FlashLite(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .gemini20FlashLite, apiKey: apiKey))
    }

    static func gemini15Pro(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .gemini15Pro, apiKey: apiKey))
    }

    static func gemini15Flash(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .gemini15Flash, apiKey: apiKey))
    }

    // MARK: Ollama (local — no API key required)

    static func ollamaLlama32() throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .ollamaLlama32, apiKey: ""))
    }

    static func ollamaMistral() throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .ollamaMistral, apiKey: ""))
    }

    static func ollamaCustom(name: String, maxTokens: Int = 32768) throws -> AIAgentImplementation {
        let model = AIModel.ollamaCustom(name: name, maxTokens: maxTokens)
        return try AIAgentImplementation(configuration: AIConfiguration(model: model, apiKey: ""))
    }
}
