import Foundation

/// Concrete implementation of AIAgent protocol
public actor AIAgentImplementation: AIAgent {
    public let configuration: AIConfiguration

    private let openAIClient: OpenAIClient?
    private let anthropicClient: AnthropicClient?

    public init(configuration: AIConfiguration) throws {
        try configuration.validate()
        self.configuration = configuration

        // Initialize appropriate client based on provider
        switch configuration.model.provider {
        case .openai:
            self.openAIClient = OpenAIClient(configuration: configuration)
            self.anthropicClient = nil
        case .anthropic:
            self.openAIClient = nil
            self.anthropicClient = AnthropicClient(configuration: configuration)
        }
    }

    // MARK: - AIAgent Protocol

    public func send(messages: [AIMessage]) async throws -> AIMessage {
        // Validate token count
        try TokenEstimator.validate(
            messages: messages,
            model: configuration.model,
            maxResponseTokens: configuration.maxResponseTokens
        )

        // Route to appropriate client
        switch configuration.model.provider {
        case .openai:
            guard let client = openAIClient else {
                throw AIError.invalidContext("OpenAI client not initialized")
            }
            return try await client.sendCompletion(messages: messages)

        case .anthropic:
            guard let client = anthropicClient else {
                throw AIError.invalidContext("Anthropic client not initialized")
            }
            return try await client.sendCompletion(messages: messages)
        }
    }

    public func stream(messages: [AIMessage]) -> AsyncThrowingStream<String, Error> {
        guard configuration.model.supportsStreaming else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: AIError.streamingError("Model does not support streaming"))
            }
        }

        // Validate token count
        do {
            try TokenEstimator.validate(
                messages: messages,
                model: configuration.model,
                maxResponseTokens: configuration.maxResponseTokens
            )
        } catch {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: error)
            }
        }

        // Route to appropriate client
        switch configuration.model.provider {
        case .openai:
            guard let client = openAIClient else {
                return AsyncThrowingStream { continuation in
                    continuation.finish(throwing: AIError.invalidContext("OpenAI client not initialized"))
                }
            }
            return client.streamCompletion(messages: messages)

        case .anthropic:
            guard let client = anthropicClient else {
                return AsyncThrowingStream { continuation in
                    continuation.finish(throwing: AIError.invalidContext("Anthropic client not initialized"))
                }
            }
            return client.streamCompletion(messages: messages)
        }
    }
}

// MARK: - Convenience Initializers

public extension AIAgentImplementation {
    /// Create an agent with OpenAI GPT-4
    static func gpt4(apiKey: String) throws -> AIAgentImplementation {
        let config = AIConfiguration(model: .gpt4, apiKey: apiKey)
        return try AIAgentImplementation(configuration: config)
    }

    /// Create an agent with OpenAI GPT-4 Turbo
    static func gpt4Turbo(apiKey: String) throws -> AIAgentImplementation {
        let config = AIConfiguration(model: .gpt4Turbo, apiKey: apiKey)
        return try AIAgentImplementation(configuration: config)
    }

    /// Create an agent with Claude 3 Opus
    static func claude3Opus(apiKey: String) throws -> AIAgentImplementation {
        let config = AIConfiguration(model: .claude3Opus, apiKey: apiKey)
        return try AIAgentImplementation(configuration: config)
    }

    /// Create an agent with Claude 3 Sonnet
    static func claude3Sonnet(apiKey: String) throws -> AIAgentImplementation {
        let config = AIConfiguration(model: .claude3Sonnet, apiKey: apiKey)
        return try AIAgentImplementation(configuration: config)
    }
}
