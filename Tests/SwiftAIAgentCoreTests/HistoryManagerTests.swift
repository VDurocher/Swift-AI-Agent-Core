import XCTest
import SwiftData
@testable import SwiftAIAgentCore

@available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
final class HistoryManagerTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a HistoryManager with an in-memory-only ModelContainer (isolated per test)
    private func makeHistoryManager() async throws -> (HistoryManager, ModelContainer) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ConversationRecord.self, MessageRecord.self,
            configurations: config
        )
        let manager = HistoryManager(modelContainer: container)
        return (manager, container)
    }

    // MARK: - Tests

    /// Verifies that saveConversation correctly persists messages in the container
    func testSaveConversation() async throws {
        let (manager, _) = try await makeHistoryManager()

        let messages: [AIMessage] = [
            .user("Hello"),
            .assistant("Hello, how can I help you?")
        ]
        let response = AIMessage.assistant("I am here to help.")

        try await manager.saveConversation(
            messages: messages,
            response: response,
            modelName: "gpt-4o"
        )

        let conversations = try await manager.loadConversations()
        XCTAssertEqual(conversations.count, 1)
        // 2 sent messages + 1 response = 3 persisted messages
        XCTAssertEqual(conversations[0].messages.count, 3)
        XCTAssertEqual(conversations[0].model, "gpt-4o")
    }

    /// Verifies that loadConversations returns conversations in descending order
    func testLoadConversationsOrder() async throws {
        let (manager, _) = try await makeHistoryManager()

        // First conversation
        try await manager.saveConversation(
            messages: [.user("First message")],
            response: .assistant("First response"),
            modelName: "gpt-4o"
        )

        // Small pause to ensure distinct timestamps
        try await Task.sleep(nanoseconds: 10_000_000)

        // Second conversation (more recent)
        try await manager.saveConversation(
            messages: [.user("Second message")],
            response: .assistant("Second response"),
            modelName: "claude-sonnet-4-6"
        )

        let conversations = try await manager.loadConversations()
        XCTAssertEqual(conversations.count, 2)
        // Most recent must be first (descending order)
        XCTAssertEqual(conversations[0].model, "claude-sonnet-4-6")
        XCTAssertEqual(conversations[1].model, "gpt-4o")
    }

    /// Verifies that loadPreviousContext respects the message limit
    func testLoadPreviousContextLimit() async throws {
        let (manager, _) = try await makeHistoryManager()

        // Create 5 user messages + 1 response = 6 messages total
        let messages: [AIMessage] = (1...5).map { .user("Message \($0)") }
        let response = AIMessage.assistant("Final response")

        try await manager.saveConversation(
            messages: messages,
            response: response,
            modelName: "gpt-4o"
        )

        // Limit to 3 messages
        let context = try await manager.loadPreviousContext(limit: 3)
        XCTAssertEqual(context.count, 3)
    }

    /// Verifies that deleteConversation correctly removes the targeted conversation
    func testDeleteConversation() async throws {
        let (manager, _) = try await makeHistoryManager()

        try await manager.saveConversation(
            messages: [.user("To delete")],
            response: .assistant("Response"),
            modelName: "gpt-4o"
        )

        let conversations = try await manager.loadConversations()
        XCTAssertEqual(conversations.count, 1)

        let targetID = conversations[0].id
        try await manager.deleteConversation(id: targetID)

        let remaining = try await manager.loadConversations()
        XCTAssertEqual(remaining.count, 0)
    }

    /// Verifies that the system prompt is correctly persisted with the conversation
    func testSaveConversationWithSystemPrompt() async throws {
        let (manager, _) = try await makeHistoryManager()

        let messages: [AIMessage] = [
            .system("You are a Swift expert assistant."),
            .user("How does async/await work?")
        ]
        let response = AIMessage.assistant("async/await is a concurrency mechanism...")

        try await manager.saveConversation(
            messages: messages,
            response: response,
            modelName: "claude-35-sonnet"
        )

        let conversations = try await manager.loadConversations()
        XCTAssertEqual(conversations.count, 1)
        XCTAssertEqual(conversations[0].systemPrompt, "You are a Swift expert assistant.")
    }

    /// Verifies that conversationToMessages correctly converts records to AIMessage
    func testConversationToMessages() async throws {
        let (manager, _) = try await makeHistoryManager()

        let originalMessages: [AIMessage] = [
            .user("Question"),
            .assistant("Intermediate response")
        ]
        let response = AIMessage.assistant("Final response")

        try await manager.saveConversation(
            messages: originalMessages,
            response: response,
            modelName: "gpt-4o"
        )

        let conversations = try await manager.loadConversations()
        XCTAssertEqual(conversations.count, 1)

        let converted = await manager.conversationToMessages(conversations[0])

        // Verify the total number of converted messages
        XCTAssertEqual(converted.count, 3)

        // Verify that roles are correctly restored
        XCTAssertEqual(converted[0].role, .user)
        XCTAssertEqual(converted[1].role, .assistant)
        XCTAssertEqual(converted[2].role, .assistant)

        // Verify message content
        XCTAssertEqual(converted[0].content, "Question")
        XCTAssertEqual(converted[2].content, "Final response")
    }
}
