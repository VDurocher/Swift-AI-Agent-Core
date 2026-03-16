import XCTest
@testable import SwiftAIAgentCore

final class TokenEstimatorTests: XCTestCase {

    func testBasicEstimation() {
        let text = "Hello, world!"
        let tokens = TokenEstimator.estimate(text: text)
        XCTAssertGreaterThan(tokens, 0)
        XCTAssertLessThan(tokens, 10)
    }

    func testLongerTextEstimation() {
        let text = String(repeating: "word ", count: 100)
        let tokens = TokenEstimator.estimate(text: text)
        XCTAssertGreaterThan(tokens, 50)
        XCTAssertLessThan(tokens, 200)
    }

    func testMessageArrayEstimation() {
        let messages = [
            AIMessage.user("Hello"),
            AIMessage.assistant("Hi there!"),
            AIMessage.user("How are you?")
        ]
        let tokens = TokenEstimator.estimate(messages: messages)
        XCTAssertGreaterThan(tokens, 0)
    }

    func testFitsWithinLimit() {
        let messages = [AIMessage.user("Short message")]
        XCTAssertTrue(TokenEstimator.fitsWithin(messages: messages, limit: 1000))
        XCTAssertFalse(TokenEstimator.fitsWithin(messages: messages, limit: 1))
    }

    func testValidation() throws {
        let messages = [AIMessage.user("Test")]
        let model = AIModel.gpt4

        // Should not throw for valid messages
        XCTAssertNoThrow(
            try TokenEstimator.validate(
                messages: messages,
                model: model,
                maxResponseTokens: 100
            )
        )

        // Should throw for excessive tokens
        let hugeMessage = AIMessage.user(String(repeating: "word ", count: 100000))
        XCTAssertThrowsError(
            try TokenEstimator.validate(
                messages: [hugeMessage],
                model: model,
                maxResponseTokens: 100
            )
        ) { error in
            XCTAssertTrue(error is AIError)
        }
    }

    func testTruncation() {
        let messages = [
            AIMessage.system("System prompt"),
            AIMessage.user("Message 1"),
            AIMessage.assistant("Response 1"),
            AIMessage.user("Message 2"),
            AIMessage.assistant("Response 2"),
            AIMessage.user("Message 3")
        ]

        let truncated = TokenEstimator.truncate(
            messages: messages,
            limit: 50,
            keepSystemMessages: true
        )

        // Should keep system message
        XCTAssertTrue(truncated.contains(where: { $0.role == .system }))

        // Should have fewer messages than original
        XCTAssertLessThan(truncated.count, messages.count)
    }
}
