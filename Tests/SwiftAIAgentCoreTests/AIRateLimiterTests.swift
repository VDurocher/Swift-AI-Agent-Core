import Testing
import Foundation
@testable import SwiftAIAgentCore

@Suite("AIRateLimiter")
struct AIRateLimiterTests {

    @Test("allows requests under the limit without waiting")
    func allowsRequestsUnderLimit() async throws {
        let limiter = AIRateLimiter(requestsPerMinute: 60)

        // Fire 5 requests in a row — all should complete immediately
        for _ in 0..<5 {
            try await limiter.acquire()
        }

        let load = await limiter.currentLoad
        #expect(load == 5)
    }

    @Test("currentLoad reflects active window entries")
    func currentLoadMatchesAcquiredCount() async throws {
        let limiter = AIRateLimiter(requestsPerMinute: 100)

        try await limiter.acquire()
        try await limiter.acquire()
        try await limiter.acquire()

        let load = await limiter.currentLoad
        #expect(load == 3)
    }

    @Test("utilization is 0 for a fresh limiter")
    func utilizationIsZeroInitially() async {
        let limiter = AIRateLimiter(requestsPerMinute: 10)
        let utilization = await limiter.utilization
        #expect(utilization == 0.0)
    }

    @Test("utilization approaches 1 when near capacity")
    func utilizationNearCapacity() async throws {
        let limiter = AIRateLimiter(requestsPerMinute: 4)

        for _ in 0..<3 {
            try await limiter.acquire()
        }

        let utilization = await limiter.utilization
        #expect(utilization == 0.75)
    }
}
