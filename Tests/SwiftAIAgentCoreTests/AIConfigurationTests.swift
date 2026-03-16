import XCTest
@testable import SwiftAIAgentCore

final class AIConfigurationTests: XCTestCase {

    func testValidConfiguration() throws {
        let config = AIConfiguration(
            model: .gpt4,
            apiKey: "test-key",
            temperature: 0.7,
            maxResponseTokens: 1000
        )

        XCTAssertNoThrow(try config.validate())
    }

    func testInvalidAPIKey() {
        let config = AIConfiguration(
            model: .gpt4,
            apiKey: "",
            temperature: 0.7
        )

        XCTAssertThrowsError(try config.validate()) { error in
            guard case AIError.invalidAPIKey = error else {
                XCTFail("Expected invalidAPIKey error")
                return
            }
        }
    }

    func testInvalidTemperature() {
        let config = AIConfiguration(
            model: .gpt4,
            apiKey: "test-key",
            temperature: 3.0
        )

        XCTAssertThrowsError(try config.validate())
    }

    func testInvalidMaxTokens() {
        let config = AIConfiguration(
            model: .gpt4,
            apiKey: "test-key",
            maxResponseTokens: 0
        )

        XCTAssertThrowsError(try config.validate())
    }

    func testRetryPolicyDelay() {
        let policy = RetryPolicy(
            maxRetries: 3,
            initialDelay: 1.0,
            maxDelay: 10.0,
            multiplier: 2.0
        )

        XCTAssertEqual(policy.delay(for: 0), 1.0)
        XCTAssertEqual(policy.delay(for: 1), 2.0)
        XCTAssertEqual(policy.delay(for: 2), 4.0)
        XCTAssertEqual(policy.delay(for: 3), 8.0)
        XCTAssertEqual(policy.delay(for: 4), 10.0) // Capped at maxDelay
    }

    func testRetryPolicyPresets() {
        XCTAssertEqual(RetryPolicy.default.maxRetries, 3)
        XCTAssertEqual(RetryPolicy.none.maxRetries, 0)
        XCTAssertEqual(RetryPolicy.aggressive.maxRetries, 5)
    }
}
