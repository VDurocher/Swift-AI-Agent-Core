import Foundation

/// Comprehensive error types for AI agent operations
public enum AIError: LocalizedError, Sendable {
    case invalidAPIKey
    case invalidContext(String)
    case rateLimit(retryAfter: TimeInterval?)
    case tokenLimitExceeded(current: Int, max: Int)
    case networkError(Error)
    case invalidResponse(statusCode: Int, message: String?)
    case decodingError(Error)
    case streamingError(String)
    case timeout
    case cancelled
    case unknown(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid or missing API key. Please check your configuration."
        case .invalidContext(let reason):
            return "Invalid context: \(reason)"
        case .rateLimit(let retryAfter):
            if let retry = retryAfter {
                return "Rate limit exceeded. Retry after \(Int(retry)) seconds."
            }
            return "Rate limit exceeded. Please try again later."
        case .tokenLimitExceeded(let current, let max):
            return "Token limit exceeded: \(current) tokens (max: \(max))"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse(let statusCode, let message):
            let msg = message ?? "Unknown error"
            return "Invalid response (HTTP \(statusCode)): \(msg)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .streamingError(let reason):
            return "Streaming error: \(reason)"
        case .timeout:
            return "Request timed out"
        case .cancelled:
            return "Request was cancelled"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }

    /// Whether this error is recoverable with retry
    public var isRecoverable: Bool {
        switch self {
        case .rateLimit, .networkError, .timeout:
            return true
        default:
            return false
        }
    }
}
