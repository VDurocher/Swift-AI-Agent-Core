import Foundation

/// Protocol defining the core AI agent interface
public protocol AIAgent: Sendable {
    /// Configuration for this agent
    var configuration: AIConfiguration { get }

    /// Send a single message and get a response
    /// - Parameter message: The message to send
    /// - Returns: The AI's response
    /// - Throws: AIError if the request fails
    func send(message: String) async throws -> String

    /// Send a conversation history and get a response
    /// - Parameter messages: Array of messages representing the conversation
    /// - Returns: The AI's response
    /// - Throws: AIError if the request fails
    func send(messages: [AIMessage]) async throws -> AIMessage

    /// Stream a response for a single message
    /// - Parameter message: The message to send
    /// - Returns: AsyncThrowingStream of response chunks
    func stream(message: String) -> AsyncThrowingStream<String, Error>

    /// Stream a response for a conversation
    /// - Parameter messages: Array of messages representing the conversation
    /// - Returns: AsyncThrowingStream of response chunks
    func stream(messages: [AIMessage]) -> AsyncThrowingStream<String, Error>

    /// Estimate token count for messages
    /// - Parameter messages: Messages to estimate
    /// - Returns: Estimated token count
    func estimateTokens(for messages: [AIMessage]) -> Int

    /// Envoie des messages avec des outils disponibles — le modèle peut décider d'appeler un outil
    /// - Parameters:
    ///   - messages: Historique de la conversation
    ///   - tools: Outils que le modèle peut invoquer
    /// - Returns: Réponse pouvant contenir du texte et/ou des appels d'outils
    func send(messages: [AIMessage], tools: [AITool]) async throws -> AIMessageWithTools

    /// Envoie les résultats d'outils dans une conversation en cours
    /// - Parameters:
    ///   - messages: Historique complet incluant le message assistant avec tool calls
    ///   - toolResults: Résultats des outils exécutés par l'application
    /// - Returns: Réponse finale du modèle après traitement des résultats
    func send(messages: [AIMessage], toolResults: [AIToolResult]) async throws -> AIMessageWithTools
}

/// Implémentations par défaut
public extension AIAgent {
    func send(message: String) async throws -> String {
        let response = try await send(messages: [.user(message)])
        return response.content
    }

    func stream(message: String) -> AsyncThrowingStream<String, Error> {
        stream(messages: [.user(message)])
    }

    func estimateTokens(for messages: [AIMessage]) -> Int {
        messages.reduce(0) { $0 + $1.estimatedTokens }
    }

    /// Implémentation par défaut : ignore les outils et effectue un appel classique
    func send(messages: [AIMessage], tools: [AITool]) async throws -> AIMessageWithTools {
        let response = try await send(messages: messages)
        return AIMessageWithTools(message: response)
    }

    /// Implémentation par défaut : concatène les résultats comme messages user et poursuit
    func send(messages: [AIMessage], toolResults: [AIToolResult]) async throws -> AIMessageWithTools {
        let resultMessages = toolResults.map { result in
            AIMessage.user("[Tool Result \(result.toolCallId)]: \(result.content)")
        }
        let allMessages = messages + resultMessages
        let response = try await send(messages: allMessages)
        return AIMessageWithTools(message: response)
    }
}
