import XCTest
@testable import SwiftAIAgentCore

final class AIMessageTests: XCTestCase {

    func testMessageCreation() {
        let message = AIMessage.user("Hello")
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, "Hello")
        XCTAssertNotNil(message.id)
    }

    func testConvenienceConstructors() {
        let userMsg = AIMessage.user("User message")
        XCTAssertEqual(userMsg.role, .user)

        let assistantMsg = AIMessage.assistant("Assistant message")
        XCTAssertEqual(assistantMsg.role, .assistant)

        let systemMsg = AIMessage.system("System message")
        XCTAssertEqual(systemMsg.role, .system)
    }

    func testMessageWithMetadata() {
        let metadata = ["key": "value", "timestamp": "123"]
        let message = AIMessage(
            role: .user,
            content: "Test",
            metadata: metadata
        )
        XCTAssertEqual(message.metadata?["key"], "value")
    }

    func testEstimatedTokens() {
        let message = AIMessage.user("This is a test message")
        XCTAssertGreaterThan(message.estimatedTokens, 0)
    }

    func testMessageEquality() {
        let msg1 = AIMessage(id: "123", role: .user, content: "Test")
        let msg2 = AIMessage(id: "123", role: .user, content: "Test")
        XCTAssertEqual(msg1, msg2)
    }

    func testMessageDescription() {
        let message = AIMessage.user("Hello")
        let description = message.description
        XCTAssertTrue(description.contains("USER"))
        XCTAssertTrue(description.contains("Hello"))
    }
}
