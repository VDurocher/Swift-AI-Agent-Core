import XCTest
@testable import SwiftAIAgentCore

// MARK: - Mock agent that streams tokens one by one

private struct StreamingMockAgent: AIAgent {
    let configuration: AIConfiguration
    let tokens: [String]

    func send(messages: [AIMessage]) async throws -> AIMessage {
        .assistant(tokens.joined())
    }

    func stream(messages: [AIMessage]) -> AsyncThrowingStream<String, Error> {
        let captured = tokens
        return AsyncThrowingStream { continuation in
            for token in captured {
                continuation.yield(token)
            }
            continuation.finish()
        }
    }

    func send(messages: [AIMessage], tools: [AITool]) async throws -> AIMessageWithTools {
        AIMessageWithTools(message: .assistant(tokens.joined()))
    }

    func send(messages: [AIMessage], toolResults: [AIToolResult]) async throws -> AIMessageWithTools {
        AIMessageWithTools(message: .assistant(tokens.joined()))
    }

    func sendForJSON(messages: [AIMessage]) async throws -> AIMessage {
        .assistant("{}")
    }
}

// MARK: - Tests

@MainActor
final class AIStreamingSessionTests: XCTestCase {

    private func makeSession(tokens: [String], systemPrompt: String? = nil) -> AIStreamingSession {
        let config = AIConfiguration(model: .gpt4o, apiKey: "test-key")
        let agent = StreamingMockAgent(configuration: config, tokens: tokens)
        return AIStreamingSession(agent: agent, systemPrompt: systemPrompt)
    }

    func testStreamingReturnsCompleteReply() async throws {
        let session = makeSession(tokens: ["Hello", ", ", "world", "!"])
        let result = try await session.send("Hi")
        XCTAssertEqual(result, "Hello, world!")
    }

    func testHistoryContainsUserAndAssistantMessages() async throws {
        let session = makeSession(tokens: ["Hi there"])
        try await session.send("Hello")
        // history: user + assistant (no system prompt)
        XCTAssertEqual(session.messageCount, 2)
        XCTAssertEqual(session.messages[0].role, .user)
        XCTAssertEqual(session.messages[1].role, .assistant)
    }

    func testSystemPromptPrependsToHistory() async throws {
        let session = makeSession(tokens: ["ok"], systemPrompt: "You are helpful.")
        try await session.send("test")
        // history: system + user + assistant
        XCTAssertEqual(session.messageCount, 3)
        XCTAssertEqual(session.messages[0].role, .system)
    }

    func testResetClearsHistoryButKeepsSystemPrompt() async throws {
        let session = makeSession(tokens: ["reply"], systemPrompt: "Be concise.")
        try await session.send("first message")
        session.reset()
        // Only the system message survives reset
        XCTAssertEqual(session.messageCount, 1)
        XCTAssertEqual(session.messages[0].role, .system)
    }

    func testIsStreamingIsFalseAfterCompletion() async throws {
        let session = makeSession(tokens: ["done"])
        try await session.send("go")
        XCTAssertFalse(session.isStreaming)
    }

    func testTokenCallbackReceivesEachToken() async throws {
        let session = makeSession(tokens: ["a", "b", "c"])
        var received: [String] = []
        try await session.send("go") { token in
            received.append(token)
        }
        XCTAssertEqual(received, ["a", "b", "c"])
    }
}
