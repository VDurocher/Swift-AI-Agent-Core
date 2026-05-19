import Foundation

// Stateful streaming session around an AIAgent.
// Maintains conversation history while streaming each reply token-by-token.
// Use when you need live UI updates (typing indicator, progressive text reveal).
@MainActor
public final class AIStreamingSession {

    private let agent: any AIAgent
    public private(set) var messages: [AIMessage] = []

    // Emitted tokens for the current in-progress reply.
    // Resets to empty at the start of each new send() call.
    public private(set) var pendingTokens: String = ""

    // True while a streaming response is in progress.
    public private(set) var isStreaming: Bool = false

    public init(agent: any AIAgent, systemPrompt: String? = nil) {
        self.agent = agent
        if let prompt = systemPrompt {
            messages = [.system(prompt)]
        }
    }

    // MARK: - Streaming send

    /// Stream a user message, yielding each token to `onToken`, then appending
    /// the completed assistant reply to history.
    ///
    /// - Parameters:
    ///   - text: The user's message.
    ///   - onToken: Called on the main actor for each streamed token.
    /// - Returns: The complete assistant reply.
    @discardableResult
    public func send(
        _ text: String,
        onToken: @MainActor (String) -> Void = { _ in }
    ) async throws -> String {
        guard !isStreaming else {
            throw AIStreamingError.alreadyStreaming
        }

        isStreaming = true
        pendingTokens = ""
        messages.append(.user(text))

        defer { isStreaming = false }

        var accumulated = ""
        for try await token in agent.stream(messages: messages) {
            accumulated += token
            pendingTokens = accumulated
            onToken(token)
        }

        let reply = AIMessage.assistant(accumulated)
        messages.append(reply)
        pendingTokens = ""
        return accumulated
    }

    // MARK: - History management

    public func reset() {
        messages = messages.filter { $0.role == .system }
        pendingTokens = ""
    }

    public var messageCount: Int { messages.count }
}

// MARK: - Errors

public enum AIStreamingError: Error, Sendable {
    // A new send() was called while a previous stream was still active.
    case alreadyStreaming
}
