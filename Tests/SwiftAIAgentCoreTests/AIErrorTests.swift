import XCTest
@testable import SwiftAIAgentCore

final class AIErrorTests: XCTestCase {

    func testErrorDescriptions() {
        let invalidKeyError = AIError.invalidAPIKey
        XCTAssertTrue(invalidKeyError.errorDescription?.contains("API key") ?? false)

        let rateLimitError = AIError.rateLimit(retryAfter: 60)
        XCTAssertTrue(rateLimitError.errorDescription?.contains("Rate limit") ?? false)

        let tokenError = AIError.tokenLimitExceeded(current: 1000, max: 500)
        XCTAssertTrue(tokenError.errorDescription?.contains("1000") ?? false)
    }

    func testRecoverableErrors() {
        XCTAssertTrue(AIError.rateLimit(retryAfter: nil).isRecoverable)
        XCTAssertTrue(AIError.timeout.isRecoverable)
        XCTAssertTrue(AIError.networkError(NSError(domain: "", code: 0)).isRecoverable)

        XCTAssertFalse(AIError.invalidAPIKey.isRecoverable)
        XCTAssertFalse(AIError.cancelled.isRecoverable)
    }

    func testRateLimitWithRetryAfter() {
        let error = AIError.rateLimit(retryAfter: 30)
        if case .rateLimit(let retryAfter) = error {
            XCTAssertEqual(retryAfter, 30)
        } else {
            XCTFail("Expected rateLimit error")
        }
    }

    func testInvalidResponse() {
        let error = AIError.invalidResponse(statusCode: 404, message: "Not found")
        XCTAssertTrue(error.errorDescription?.contains("404") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("Not found") ?? false)
    }
}
