import Foundation

/// Implémentation concrète du protocole AIAgent.
/// Supporte plusieurs providers LLM et, sur iOS 17+, la persistance locale via SwiftData.
public actor AIAgentImplementation: AIAgent {
    public let configuration: AIConfiguration

    private let openAIClient: OpenAIClient?
    private let anthropicClient: AnthropicClient?

    /// Stockage type-erased du HistoryManager pour éviter la contrainte @available
    /// sur une propriété stockée. Accédé via la propriété calculée `historyManager`.
    private let _historyManager: Any?

    /// Gestionnaire d'historique SwiftData (iOS 17+ / macOS 14+ uniquement)
    @available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
    private var historyManager: HistoryManager? {
        _historyManager as? HistoryManager
    }

    // MARK: - Initialiseurs désignés

    /// Initialise l'agent sans persistance locale
    public init(configuration: AIConfiguration) throws {
        try configuration.validate()
        self.configuration = configuration
        self._historyManager = nil
        let (openAI, anthropic) = Self.buildClients(configuration: configuration)
        self.openAIClient = openAI
        self.anthropicClient = anthropic
    }

    /// Initialise l'agent avec persistance locale via SwiftData (iOS 17+ / macOS 14+)
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
        // Validation du nombre de tokens avant l'envoi
        try TokenEstimator.validate(
            messages: messages,
            model: configuration.model,
            maxResponseTokens: configuration.maxResponseTokens
        )

        // Routage vers le client approprié
        let response: AIMessage
        switch configuration.model.provider {
        case .openai:
            guard let client = openAIClient else {
                throw AIError.invalidContext("OpenAI client not initialized")
            }
            response = try await client.sendCompletion(messages: messages)

        case .anthropic:
            guard let client = anthropicClient else {
                throw AIError.invalidContext("Anthropic client not initialized")
            }
            response = try await client.sendCompletion(messages: messages)
        }

        // Sauvegarde dans l'historique si un gestionnaire est configuré (iOS 17+ seulement)
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

    public func stream(messages: [AIMessage]) -> AsyncThrowingStream<String, Error> {
        guard configuration.model.supportsStreaming else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: AIError.streamingError("Model does not support streaming"))
            }
        }

        // Validation du nombre de tokens
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

        // Routage vers le client approprié
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

    // MARK: - Persistance locale (iOS 17+ / macOS 14+)

    /// Charge les N derniers messages de la conversation la plus récente
    /// pour alimenter le contexte de l'agent entre les sessions
    @available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
    public func loadPreviousContext(limit: Int = 20) async throws -> [AIMessage] {
        guard let manager = historyManager else { return [] }
        return try await manager.loadPreviousContext(limit: limit)
    }
}

// MARK: - Helpers privés

private extension AIAgentImplementation {
    /// Crée les clients réseau selon le provider configuré
    static func buildClients(
        configuration: AIConfiguration
    ) -> (openAI: OpenAIClient?, anthropic: AnthropicClient?) {
        switch configuration.model.provider {
        case .openai:
            return (OpenAIClient(configuration: configuration), nil)
        case .anthropic:
            return (nil, AnthropicClient(configuration: configuration))
        }
    }
}

// MARK: - Convenience Initializers

public extension AIAgentImplementation {
    /// Crée un agent GPT-4
    static func gpt4(apiKey: String) throws -> AIAgentImplementation {
        let config = AIConfiguration(model: .gpt4, apiKey: apiKey)
        return try AIAgentImplementation(configuration: config)
    }

    /// Crée un agent GPT-4 Turbo
    static func gpt4Turbo(apiKey: String) throws -> AIAgentImplementation {
        let config = AIConfiguration(model: .gpt4Turbo, apiKey: apiKey)
        return try AIAgentImplementation(configuration: config)
    }

    /// Crée un agent Claude 3 Opus
    static func claude3Opus(apiKey: String) throws -> AIAgentImplementation {
        let config = AIConfiguration(model: .claude3Opus, apiKey: apiKey)
        return try AIAgentImplementation(configuration: config)
    }

    /// Crée un agent Claude 3 Sonnet
    static func claude3Sonnet(apiKey: String) throws -> AIAgentImplementation {
        let config = AIConfiguration(model: .claude3Sonnet, apiKey: apiKey)
        return try AIAgentImplementation(configuration: config)
    }

    /// Crée un agent GPT-4o (multimodal, 128k contexte)
    static func gpt4o(apiKey: String) throws -> AIAgentImplementation {
        let config = AIConfiguration(model: .gpt4o, apiKey: apiKey)
        return try AIAgentImplementation(configuration: config)
    }

    /// Crée un agent GPT-4o Mini (rapide et économique)
    static func gpt4oMini(apiKey: String) throws -> AIAgentImplementation {
        let config = AIConfiguration(model: .gpt4oMini, apiKey: apiKey)
        return try AIAgentImplementation(configuration: config)
    }

    /// Crée un agent Claude 3.5 Sonnet (haute performance, 200k contexte)
    static func claude35Sonnet(apiKey: String) throws -> AIAgentImplementation {
        let config = AIConfiguration(model: .claude35Sonnet, apiKey: apiKey)
        return try AIAgentImplementation(configuration: config)
    }

    /// Crée un agent Claude Sonnet 4.6 — dernier modèle Anthropic disponible
    static func claudeSonnet46(apiKey: String) throws -> AIAgentImplementation {
        let config = AIConfiguration(model: .claudeSonnet46, apiKey: apiKey)
        return try AIAgentImplementation(configuration: config)
    }
}
