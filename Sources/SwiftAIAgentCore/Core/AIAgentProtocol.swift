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
}

/// Default implementations
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
}
