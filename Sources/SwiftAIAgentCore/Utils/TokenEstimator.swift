import Foundation

/// Utility for estimating token counts before sending requests
///
/// This is a simplified estimation based on character count and word patterns.
/// For production use, consider using a proper tokenizer library like tiktoken.
public enum TokenEstimator: Sendable {

    /// Estimate token count for a given text
    /// - Parameter text: The text to estimate
    /// - Returns: Estimated token count
    public static func estimate(text: String) -> Int {
        // Rough estimation: ~4 characters per token for English text
        // This is a simplified approach; actual tokenization varies by model

        let characterCount = text.count
        let wordCount = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count

        // Average of character-based and word-based estimation
        let charBasedEstimate = characterCount / 4
        let wordBasedEstimate = Int(Double(wordCount) * 1.3)

        return (charBasedEstimate + wordBasedEstimate) / 2
    }

    /// Estimate tokens for an array of messages
    /// - Parameter messages: Messages to estimate
    /// - Returns: Total estimated token count
    public static func estimate(messages: [AIMessage]) -> Int {
        messages.reduce(0) { total, message in
            total + estimate(text: message.content) + 4 // +4 for message formatting overhead
        }
    }

    /// Check if messages fit within a token limit
    /// - Parameters:
    ///   - messages: Messages to check
    ///   - limit: Token limit
    /// - Returns: true if within limit, false otherwise
    public static func fitsWithin(messages: [AIMessage], limit: Int) -> Bool {
        estimate(messages: messages) <= limit
    }

    /// Estimate tokens needed including response
    /// - Parameters:
    ///   - messages: Input messages
    ///   - maxResponseTokens: Expected response size
    /// - Returns: Total estimated tokens
    public static func estimateTotal(
        messages: [AIMessage],
        maxResponseTokens: Int
    ) -> Int {
        estimate(messages: messages) + maxResponseTokens
    }

    /// Validate messages against model limits
    /// - Parameters:
    ///   - messages: Messages to validate
    ///   - model: AI model configuration
    ///   - maxResponseTokens: Expected response size
    /// - Throws: AIError.tokenLimitExceeded if over limit
    public static func validate(
        messages: [AIMessage],
        model: AIModel,
        maxResponseTokens: Int
    ) throws {
        let total = estimateTotal(messages: messages, maxResponseTokens: maxResponseTokens)

        if total > model.maxTokens {
            throw AIError.tokenLimitExceeded(current: total, max: model.maxTokens)
        }
    }

    /// Truncate messages to fit within token limit
    /// - Parameters:
    ///   - messages: Messages to truncate
    ///   - limit: Token limit
    ///   - keepSystemMessages: Whether to preserve system messages
    /// - Returns: Truncated message array
    public static func truncate(
        messages: [AIMessage],
        limit: Int,
        keepSystemMessages: Bool = true
    ) -> [AIMessage] {
        var result: [AIMessage] = []
        var currentTokens = 0

        // Keep system messages first if requested
        if keepSystemMessages {
            let systemMessages = messages.filter { $0.role == .system }
            for msg in systemMessages {
                let tokens = estimate(text: msg.content)
                if currentTokens + tokens <= limit {
                    result.append(msg)
                    currentTokens += tokens
                }
            }
        }

        // Add remaining messages from newest to oldest
        let nonSystemMessages = messages.filter { $0.role != .system }.reversed()
        for msg in nonSystemMessages {
            let tokens = estimate(text: msg.content)
            if currentTokens + tokens <= limit {
                result.insert(msg, at: keepSystemMessages ? result.count : 0)
                currentTokens += tokens
            } else {
                break
            }
        }

        return result
    }
}
