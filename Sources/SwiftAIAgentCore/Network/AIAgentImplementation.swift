import Foundation

/// Concrete implementation of the AIAgent protocol.
/// Supports multiple LLM providers and, on iOS 17+, local persistence via SwiftData.
public actor AIAgentImplementation: AIAgent {
    public let configuration: AIConfiguration

    private let openAIClient: OpenAIClient?
    private let anthropicClient: AnthropicClient?

    /// Type-erased storage for HistoryManager to avoid placing a @available constraint
    /// on a stored property. Accessed via the computed property `historyManager`.
    private let _historyManager: Any?

    /// SwiftData history manager (iOS 17+ / macOS 14+ only)
    @available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
    private var historyManager: HistoryManager? {
        _historyManager as? HistoryManager
    }

    // MARK: - Designated Initializers

    /// Initializes the agent without local persistence
    public init(configuration: AIConfiguration) throws {
        try configuration.validate()
        self.configuration = configuration
        self._historyManager = nil
        let (openAI, anthropic) = Self.buildClients(configuration: configuration)
        self.openAIClient = openAI
        self.anthropicClient = anthropic
    }

    /// Initializes the agent with local persistence via SwiftData (iOS 17+ / macOS 14+)
    @available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
    public init(configuration: AIConfiguration, historyManager: HistoryManager) throws {
        try configuration.validate()
        self.configuration = configuration
        self._historyManager = historyManager
        let (openAI, anthropic) = Self.buildClients(configuration: configuration)
        self.openAIClient = openAI
        self.anthropicClient = anthropic
    }

    // MARK: - AIAgent Protocol

    public func send(messages: [AIMessage]) async throws -> AIMessage {
        // Validate token count before sending
        try TokenEstimator.validate(
            messages: messages,
            model: configuration.model,
            maxResponseTokens: configuration.maxResponseTokens
        )

        // Route to the appropriate client
        let response: AIMessage
        switch configuration.model.provider {
        case .openai, .gemini:
            // Gemini uses the OpenAI-compatible endpoint — same client handles both
            guard let client = openAIClient else {
                throw AIError.invalidContext("OpenAI/Gemini client not initialized")
            }
            response = try await client.sendCompletion(messages: messages)

        case .anthropic:
            guard let client = anthropicClient else {
                throw AIError.invalidContext("Anthropic client not initialized")
            }
            response = try await client.sendCompletion(messages: messages)
        }

        // Save to history if a manager is configured (iOS 17+ only)
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

    public func send(messages: [AIMessage], tools: [AITool]) async throws -> AIMessageWithTools {
        // Validate token count before sending
        try TokenEstimator.validate(
            messages: messages,
            model: configuration.model,
            maxResponseTokens: configuration.maxResponseTokens
        )

        // Route to the appropriate client with tool support
        switch configuration.model.provider {
        case .openai, .gemini:
            guard let client = openAIClient else {
                throw AIError.invalidContext("OpenAI/Gemini client not initialized")
            }
            return try await client.sendCompletionWithTools(messages: messages, tools: tools)

        case .anthropic:
            guard let client = anthropicClient else {
                throw AIError.invalidContext("Anthropic client not initialized")
            }
            return try await client.sendCompletionWithTools(messages: messages, tools: tools)
        }
    }

    public func send(messages: [AIMessage], toolResults: [AIToolResult]) async throws -> AIMessageWithTools {
        // Convert tool results into AIMessage values with the .tool role.
        // OpenAI and Anthropic clients read the "tool_call_id" metadata key to build the request.
        let toolResultMessages: [AIMessage] = toolResults.map { result in
            AIMessage(
                role: .tool,
                content: result.content,
                metadata: ["tool_call_id": result.toolCallId]
            )
        }

        // Append results to the existing history and issue a new call without tools.
        // The model processes the results and produces its final response.
        let fullMessages = messages + toolResultMessages

        try TokenEstimator.validate(
            messages: fullMessages,
            model: configuration.model,
            maxResponseTokens: configuration.maxResponseTokens
        )

        switch configuration.model.provider {
        case .openai, .gemini:
            guard let client = openAIClient else {
                throw AIError.invalidContext("OpenAI/Gemini client not initialized")
            }
            // Send without additional tools — the model produces the final response
            let response = try await client.sendCompletion(messages: fullMessages)
            return AIMessageWithTools(message: response)

        case .anthropic:
            guard let client = anthropicClient else {
                throw AIError.invalidContext("Anthropic client not initialized")
            }
            // Send without additional tools — the model produces the final response
            let response = try await client.sendCompletion(messages: fullMessages)
            return AIMessageWithTools(message: response)
        }
    }

    nonisolated public func stream(messages: [AIMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await chunk in try await self._streamMessages(messages) {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func _streamMessages(_ messages: [AIMessage]) async throws -> AsyncThrowingStream<String, Error> {
        guard configuration.model.supportsStreaming else {
            throw AIError.streamingError("Model does not support streaming")
        }

        // Validate token count before streaming
        try TokenEstimator.validate(
            messages: messages,
            model: configuration.model,
            maxResponseTokens: configuration.maxResponseTokens
        )

        // Route to the appropriate client
        switch configuration.model.provider {
        case .openai, .gemini:
            guard let client = openAIClient else {
                throw AIError.invalidContext("OpenAI/Gemini client not initialized")
            }
            return await client.streamCompletion(messages: messages)

        case .anthropic:
            guard let client = anthropicClient else {
                throw AIError.invalidContext("Anthropic client not initialized")
            }
            return await client.streamCompletion(messages: messages)
        }
    }

    // MARK: - Local Persistence (iOS 17+ / macOS 14+)

    /// Loads the last N messages from the most recent conversation
    /// to seed the agent's context across sessions
    @available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
    public func loadPreviousContext(limit: Int = 20) async throws -> [AIMessage] {
        guard let manager = historyManager else { return [] }
        return try await manager.loadPreviousContext(limit: limit)
    }
}

// MARK: - Private Helpers

private extension AIAgentImplementation {
    /// Creates network clients based on the configured provider.
    /// Gemini uses the OpenAI-compatible endpoint, so it reuses OpenAIClient.
    static func buildClients(
        configuration: AIConfiguration
    ) -> (openAI: OpenAIClient?, anthropic: AnthropicClient?) {
        switch configuration.model.provider {
        case .openai, .gemini:
            return (OpenAIClient(configuration: configuration), nil)
        case .anthropic:
            return (nil, AnthropicClient(configuration: configuration))
        }
    }
}

// MARK: - Convenience Initializers

public extension AIAgentImplementation {

    // MARK: OpenAI

    /// Creates a GPT-4 agent (8k context)
    static func gpt4(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .gpt4, apiKey: apiKey))
    }

    /// Creates a GPT-4 Turbo agent (128k context)
    static func gpt4Turbo(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .gpt4Turbo, apiKey: apiKey))
    }

    /// Creates a GPT-3.5 Turbo agent (16k context, fast and cost-efficient)
    static func gpt35Turbo(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .gpt35Turbo, apiKey: apiKey))
    }

    /// Creates a GPT-4o agent (128k context, multimodal)
    static func gpt4o(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .gpt4o, apiKey: apiKey))
    }

    /// Creates a GPT-4o Mini agent (128k context, fast and cost-efficient)
    static func gpt4oMini(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .gpt4oMini, apiKey: apiKey))
    }

    // MARK: Anthropic — Claude 3

    /// Creates a Claude 3 Haiku agent (200k context, fastest Claude 3)
    static func claude3Haiku(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .claude3Haiku, apiKey: apiKey))
    }

    /// Creates a Claude 3 Sonnet agent (200k context)
    static func claude3Sonnet(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .claude3Sonnet, apiKey: apiKey))
    }

    /// Creates a Claude 3 Opus agent (200k context, most capable Claude 3)
    static func claude3Opus(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .claude3Opus, apiKey: apiKey))
    }

    // MARK: Anthropic — Claude 3.5

    /// Creates a Claude 3.5 Haiku agent (200k context, fast and cost-efficient)
    static func claude35Haiku(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .claude35Haiku, apiKey: apiKey))
    }

    /// Creates a Claude 3.5 Sonnet agent (200k context, high performance)
    static func claude35Sonnet(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .claude35Sonnet, apiKey: apiKey))
    }

    // MARK: Anthropic — Claude 4

    /// Creates a Claude Haiku 4.5 agent (200k context, fastest Claude 4)
    static func claudeHaiku45(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .claudeHaiku45, apiKey: apiKey))
    }

    /// Creates a Claude Sonnet 4.6 agent (200k context)
    static func claudeSonnet46(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .claudeSonnet46, apiKey: apiKey))
    }

    /// Creates a Claude Opus 4.6 agent (200k context, most capable Claude 4)
    static func claudeOpus46(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .claudeOpus46, apiKey: apiKey))
    }

    // MARK: OpenAI Latest

    /// Creates a GPT-4.1 agent (1M context, April 2025)
    static func gpt41(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .gpt41, apiKey: apiKey))
    }

    /// Creates a GPT-4.1 Mini agent (1M context, lightweight)
    static func gpt41Mini(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .gpt41Mini, apiKey: apiKey))
    }

    /// Creates a GPT-4.1 Nano agent (1M context, fastest GPT-4.1 variant)
    static func gpt41Nano(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .gpt41Nano, apiKey: apiKey))
    }

    /// Creates an o4-mini agent (200k context, reasoning model)
    static func o4Mini(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .o4Mini, apiKey: apiKey))
    }

    // MARK: Anthropic — Claude 3.7

    /// Creates a Claude 3.7 Sonnet agent (200k context, extended thinking)
    static func claude37Sonnet(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .claude37Sonnet, apiKey: apiKey))
    }

    // MARK: Google Gemini

    /// Creates a Gemini 2.5 Flash agent (1M context, fast and cost-efficient)
    static func gemini25Flash(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .gemini25Flash, apiKey: apiKey))
    }

    /// Creates a Gemini 2.5 Pro agent (1M context, most capable Gemini)
    static func gemini25Pro(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .gemini25Pro, apiKey: apiKey))
    }

    /// Creates a Gemini 2.0 Flash agent (1M context)
    static func gemini20Flash(apiKey: String) throws -> AIAgentImplementation {
        try AIAgentImplementation(configuration: AIConfiguration(model: .gemini20Flash, apiKey: apiKey))
    }
}
