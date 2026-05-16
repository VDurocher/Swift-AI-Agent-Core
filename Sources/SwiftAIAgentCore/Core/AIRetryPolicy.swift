import Foundation

// Configures exponential backoff retry behaviour for AI API calls.
// Attach to a client to automatically retry transient errors.
public struct AIRetryPolicy: Sendable {

    // Maximum number of retry attempts (not counting the initial attempt).
    public let maxAttempts: Int

    // Base delay before the first retry, in seconds.
    public let baseDelay: TimeInterval

    // Multiplier applied to the delay after each failed attempt.
    public let backoffMultiplier: Double

    // Upper bound on the computed delay to avoid unbounded waits.
    public let maxDelay: TimeInterval

    // When true, adds a random jitter (±10 %) to each delay to avoid thundering-herd.
    public let jitter: Bool

    public init(
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 1.0,
        backoffMultiplier: Double = 2.0,
        maxDelay: TimeInterval = 30.0,
        jitter: Bool = true
    ) {
        precondition(maxAttempts >= 0, "maxAttempts must be non-negative")
        precondition(baseDelay > 0, "baseDelay must be positive")
        precondition(backoffMultiplier >= 1, "backoffMultiplier must be >= 1")
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.backoffMultiplier = backoffMultiplier
        self.maxDelay = maxDelay
        self.jitter = jitter
    }

    // Compute the delay before attempt number `attempt` (1-based).
    public func delay(forAttempt attempt: Int) -> TimeInterval {
        guard attempt > 0 else { return 0 }
        let exponential = baseDelay * pow(backoffMultiplier, Double(attempt - 1))
        let capped = min(exponential, maxDelay)
        guard jitter else { return capped }
        // ±10 % jitter
        let factor = 0.9 + Double.random(in: 0..<0.2)
        return capped * factor
    }
}

public extension AIRetryPolicy {

    // No retries — fail immediately on first error.
    static let none = AIRetryPolicy(maxAttempts: 0)

    // Aggressive: 5 retries, starts at 500 ms.
    static let aggressive = AIRetryPolicy(maxAttempts: 5, baseDelay: 0.5)

    // Standard: 3 retries, starts at 1 s (default).
    static let standard = AIRetryPolicy()

    // Conservative: 2 retries, starts at 2 s.
    static let conservative = AIRetryPolicy(maxAttempts: 2, baseDelay: 2.0)
}
