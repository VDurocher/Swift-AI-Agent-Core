import Foundation

/// Stateful wrapper around an `AIAgent` that maintains conversation history automatically.
///
/// Use `AIConversation` when you want a chat-style interface without manually
/// tracking the message array:
///
/// ```swift
/// let agent = try AIAgentImplementation.claudeSonnet46(apiKey: "sk-ant-...")
/// let conversation = AIConversation(agent: agent, systemPrompt: "You are a Swift expert.")
///
/// let reply1 = try await conversation.send("What is an actor?")
/// let reply2 = try await conversation.send("Show me an example.")
/// // history is maintained automatically between calls
/// ```
@MainActor
public final class AIConversation {

    private let agent: any AIAgent
    public private(set) var messages: [AIMessage]

    /// Number of messages in the current conversation (including system prompt).
    public var messageCount: Int { messages.count }

    // MARK: - Init

    /// - Parameters:
    ///   - agent: The AI agent to route messages through.
    ///   - systemPrompt: Optional system instruction prepended to every request.
    public init(agent: any AIAgent, systemPrompt: String? = nil) {
        self.agent = agent
        self.messages = systemPrompt.map { [.system($0)] } ?? []
    }

    // MARK: - Send

    /// Sends a user message, appends both the user turn and assistant reply to history,
    /// and returns the assistant's response text.
    @discardableResult
    public func send(_ text: String) async throws -> String {
        let userMessage = AIMessage.user(text)
        messages.append(userMessage)

        let response = try await agent.send(messages: messages)
        messages.append(response)
        return response.content
    }

    /// Sends a user message with image attachments (vision-capable models only).
    @discardableResult
    public func send(_ text: String, images: [AIImageContent]) async throws -> String {
        let userMessage = AIMessage.user(text, images: images)
        messages.append(userMessage)

        let response = try await agent.send(messages: messages)
        messages.append(response)
        return response.content
    }

    // MARK: - History Management

    /// Resets the conversation to its initial state (system prompt only, if any).
    public func reset(keepingSystemPrompt: Bool = true) {
        if keepingSystemPrompt {
            messages = messages.filter { $0.role == .system }
        } else {
            messages = []
        }
    }

    /// Removes the last user+assistant exchange from history.
    public func undoLastExchange() {
        // Remove trailing assistant message, then trailing user message
        if messages.last?.role == .assistant { messages.removeLast() }
        if messages.last?.role == .user { messages.removeLast() }
    }

    /// Estimated token count for the current conversation.
    public var estimatedTokens: Int {
        agent.estimateTokens(for: messages)
    }
}
