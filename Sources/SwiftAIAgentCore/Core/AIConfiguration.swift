import Foundation

/// Configuration for AI agent
public struct AIConfiguration: Sendable {
    public let model: AIModel
    public let apiKey: String
    public let temperature: Double
    public let maxResponseTokens: Int
    public let timeout: TimeInterval
    public let retryPolicy: RetryPolicy

    public init(
        model: AIModel,
        apiKey: String,
        temperature: Double = 0.7,
        maxResponseTokens: Int = 2000,
        timeout: TimeInterval = 30,
        retryPolicy: RetryPolicy = .default
    ) {
        self.model = model
        self.apiKey = apiKey
        self.temperature = temperature
        self.maxResponseTokens = maxResponseTokens
        self.timeout = timeout
        self.retryPolicy = retryPolicy
    }

    /// Validate configuration
    public func validate() throws {
        guard !apiKey.isEmpty else {
            throw AIError.invalidAPIKey
        }

        guard temperature >= 0 && temperature <= 2 else {
            throw AIError.invalidContext("Temperature must be between 0 and 2")
        }

        guard maxResponseTokens > 0 && maxResponseTokens <= model.maxTokens else {
            throw AIError.invalidContext("Max response tokens must be between 1 and \(model.maxTokens)")
        }
    }
}

/// Retry policy for failed requests
public struct RetryPolicy: Sendable {
    public let maxRetries: Int
    public let initialDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let multiplier: Double

    public init(
        maxRetries: Int = 3,
        initialDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 60.0,
        multiplier: Double = 2.0
    ) {
        self.maxRetries = maxRetries
        self.initialDelay = initialDelay
        self.maxDelay = maxDelay
        self.multiplier = multiplier
    }

    public static let `default` = RetryPolicy()
    public static let none = RetryPolicy(maxRetries: 0)
    public static let aggressive = RetryPolicy(maxRetries: 5, initialDelay: 0.5, maxDelay: 30)

    /// Calculate delay for a given retry attempt
    public func delay(for attempt: Int) -> TimeInterval {
        let delay = initialDelay * pow(multiplier, Double(attempt))
        return min(delay, maxDelay)
    }
}
