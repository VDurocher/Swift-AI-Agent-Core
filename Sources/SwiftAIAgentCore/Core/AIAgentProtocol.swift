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

    /// Send messages with available tools — the model may decide to call a tool
    /// - Parameters:
    ///   - messages: Conversation history
    ///   - tools: Tools the model can invoke
    /// - Returns: Response potentially containing text and/or tool calls
    func send(messages: [AIMessage], tools: [AITool]) async throws -> AIMessageWithTools

    /// Send tool results back into an ongoing conversation
    /// - Parameters:
    ///   - messages: Full history including the assistant message with tool calls
    ///   - toolResults: Results of tools executed by the application
    /// - Returns: Final model response after processing the results
    func send(messages: [AIMessage], toolResults: [AIToolResult]) async throws -> AIMessageWithTools
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

    /// Default implementation: ignores tools and performs a standard call
    func send(messages: [AIMessage], tools: [AITool]) async throws -> AIMessageWithTools {
        let response = try await send(messages: messages)
        return AIMessageWithTools(message: response)
    }

    /// Default implementation: concatenates results as user messages and continues
    func send(messages: [AIMessage], toolResults: [AIToolResult]) async throws -> AIMessageWithTools {
        let resultMessages = toolResults.map { result in
            AIMessage.user("[Tool Result \(result.toolCallId)]: \(result.content)")
        }
        let allMessages = messages + resultMessages
        let response = try await send(messages: allMessages)
        return AIMessageWithTools(message: response)
    }
}
