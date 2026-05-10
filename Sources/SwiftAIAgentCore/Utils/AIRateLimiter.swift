import Foundation

// Token-bucket rate limiter for AI API calls.
// Prevents exceeding provider rate limits by throttling requests per minute.
public actor AIRateLimiter {

    private let requestsPerMinute: Int
    private var timestamps: [Date] = []

    public init(requestsPerMinute: Int) {
        precondition(requestsPerMinute > 0, "requestsPerMinute must be positive")
        self.requestsPerMinute = requestsPerMinute
    }

    // Wait until a request slot is available, then record the request.
    public func acquire() async throws {
        let now = Date()
        let windowStart = now.addingTimeInterval(-60)

        // Drop timestamps older than the rolling 1-minute window
        timestamps = timestamps.filter { $0 > windowStart }

        if timestamps.count >= requestsPerMinute {
            // Calculate how long to wait for the oldest slot to expire
            guard let oldest = timestamps.first else { return }
            let waitInterval = oldest.addingTimeInterval(60).timeIntervalSince(now)
            if waitInterval > 0 {
                try await Task.sleep(nanoseconds: UInt64(waitInterval * 1_000_000_000))
            }
        }

        timestamps.append(Date())
    }

    // Current number of requests in the rolling window.
    public var currentLoad: Int {
        let windowStart = Date().addingTimeInterval(-60)
        return timestamps.filter { $0 > windowStart }.count
    }

    // Fraction of capacity used (0.0 – 1.0).
    public var utilization: Double {
        Double(currentLoad) / Double(requestsPerMinute)
    }
}
