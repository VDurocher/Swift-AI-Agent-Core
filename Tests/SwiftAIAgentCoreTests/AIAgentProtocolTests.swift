import XCTest
@testable import SwiftAIAgentCore

// MARK: - Minimal mock used across protocol tests

private struct EchoAgent: AIAgent {
    let configuration: AIConfiguration

    func send(messages: [AIMessage]) async throws -> AIMessage {
        // Echo the last user message back as the assistant response
        let lastUserContent = messages.last(where: { $0.role == .user })?.content ?? ""
        return .assistant(lastUserContent)
    }

    func stream(messages: [AIMessage]) -> AsyncThrowingStream<String, Error> {
        let content = messages.last?.content ?? ""
        return AsyncThrowingStream { continuation in
            continuation.yield(content)
            continuation.finish()
        }
    }

    func send(messages: [AIMessage], tools: [AITool]) async throws -> AIMessageWithTools {
        AIMessageWithTools(message: .assistant("no tools"))
    }

    func send(messages: [AIMessage], toolResults: [AIToolResult]) async throws -> AIMessageWithTools {
        AIMessageWithTools(message: .assistant("results received"))
    }

    func sendForJSON(messages: [AIMessage]) async throws -> AIMessage {
        .assistant("{\"value\": 42}")
    }
}

final class AIAgentProtocolTests: XCTestCase {

    private func makeAgent() throws -> EchoAgent {
        let config = AIConfiguration(model: .gpt4o, apiKey: "test-key")
        return EchoAgent(configuration: config)
    }

    // MARK: - Default send(message:)

    func testSendSingleMessageReturnsContent() async throws {
        let agent = try makeAgent()
        let reply = try await agent.send(message: "Hello")
        XCTAssertEqual(reply, "Hello")
    }

    // MARK: - Default stream(message:)

    func testStreamSingleMessageYieldsContent() async throws {
        let agent = try makeAgent()
        var chunks: [String] = []
        for try await chunk in agent.stream(message: "Hi") {
            chunks.append(chunk)
        }
        XCTAssertFalse(chunks.isEmpty)
    }

    // MARK: - Structured output

    func testSendPromptAsDecodable() async throws {
        let agent = try makeAgent()

        struct Result: Decodable, Sendable { let value: Int }
        let result = try await agent.send("Give me JSON", as: Result.self)
        XCTAssertEqual(result.value, 42)
    }

    // MARK: - Token estimation

    func testEstimateTokensIsPositive() throws {
        let agent = try makeAgent()
        let messages: [AIMessage] = [.user("Hello world, this is a test message.")]
        let tokens = agent.estimateTokens(for: messages)
        XCTAssertGreaterThan(tokens, 0)
    }

    func testEstimateTokensScalesWithMessageLength() throws {
        let agent = try makeAgent()
        let short = [AIMessage.user("Hi")]
        let long = [AIMessage.user(String(repeating: "word ", count: 100))]
        XCTAssertLessThan(agent.estimateTokens(for: short), agent.estimateTokens(for: long))
    }
}
