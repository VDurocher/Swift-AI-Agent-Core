import XCTest
@testable import SwiftAIAgentCore

// MARK: - Mock agent for testing

private struct MockAgent: AIAgent {
    let configuration: AIConfiguration
    let fixedResponse: String

    func send(messages: [AIMessage]) async throws -> AIMessage {
        .assistant(fixedResponse)
    }

    func stream(messages: [AIMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(fixedResponse)
            continuation.finish()
        }
    }

    func send(messages: [AIMessage], tools: [AITool]) async throws -> AIMessageWithTools {
        AIMessageWithTools(message: .assistant(fixedResponse))
    }

    func send(messages: [AIMessage], toolResults: [AIToolResult]) async throws -> AIMessageWithTools {
        AIMessageWithTools(message: .assistant(fixedResponse))
    }

    func sendForJSON(messages: [AIMessage]) async throws -> AIMessage {
        .assistant("{}")
    }
}

// MARK: - Tests

@MainActor
final class AIConversationTests: XCTestCase {

    private func makeConversation(systemPrompt: String? = nil, response: String = "ok") throws -> AIConversation {
        let config = AIConfiguration(model: .gpt4o, apiKey: "test-key")
        let agent = MockAgent(configuration: config, fixedResponse: response)
        return AIConversation(agent: agent, systemPrompt: systemPrompt)
    }

    func testInitWithoutSystemPrompt() throws {
        let conv = try makeConversation()
        XCTAssertEqual(conv.messageCount, 0)
    }

    func testInitWithSystemPrompt() throws {
        let conv = try makeConversation(systemPrompt: "You are a tester.")
        XCTAssertEqual(conv.messageCount, 1)
        XCTAssertEqual(conv.messages.first?.role, .system)
    }

    func testSendAppendsUserAndAssistantMessages() async throws {
        let conv = try makeConversation(response: "Hello!")
        let reply = try await conv.send("Hi")
        XCTAssertEqual(reply, "Hello!")
        XCTAssertEqual(conv.messageCount, 2)
        XCTAssertEqual(conv.messages.first?.role, .user)
        XCTAssertEqual(conv.messages.last?.role, .assistant)
    }

    func testMultipleTurnsAccumulateHistory() async throws {
        let conv = try makeConversation(response: "ok")
        try await conv.send("Turn 1")
        try await conv.send("Turn 2")
        // 2 user + 2 assistant = 4
        XCTAssertEqual(conv.messageCount, 4)
    }

    func testResetKeepsSystemPrompt() async throws {
        let conv = try makeConversation(systemPrompt: "Be helpful.", response: "ok")
        try await conv.send("Hello")
        conv.reset(keepingSystemPrompt: true)
        XCTAssertEqual(conv.messageCount, 1)
        XCTAssertEqual(conv.messages.first?.role, .system)
    }

    func testResetWithoutSystemPrompt() async throws {
        let conv = try makeConversation(systemPrompt: "Be helpful.", response: "ok")
        try await conv.send("Hello")
        conv.reset(keepingSystemPrompt: false)
        XCTAssertEqual(conv.messageCount, 0)
    }

    func testUndoLastExchange() async throws {
        let conv = try makeConversation(response: "ok")
        try await conv.send("First")
        try await conv.send("Second")
        conv.undoLastExchange()
        // After undo: only the first exchange remains (2 messages)
        XCTAssertEqual(conv.messageCount, 2)
        XCTAssertEqual(conv.messages.last?.content, "ok")
    }
}
