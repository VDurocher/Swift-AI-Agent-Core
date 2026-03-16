import Foundation

/// Represents a single message in an AI conversation
public struct AIMessage: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let role: AIRole
    public let content: String
    public let timestamp: Date
    public var metadata: [String: String]?

    public init(
        id: String = UUID().uuidString,
        role: AIRole,
        content: String,
        timestamp: Date = Date(),
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.metadata = metadata
    }

    /// Create a user message
    public static func user(_ content: String) -> AIMessage {
        AIMessage(role: .user, content: content)
    }

    /// Create an assistant message
    public static func assistant(_ content: String) -> AIMessage {
        AIMessage(role: .assistant, content: content)
    }

    /// Create a system message
    public static func system(_ content: String) -> AIMessage {
        AIMessage(role: .system, content: content)
    }

    /// Estimated token count (rough approximation)
    public var estimatedTokens: Int {
        TokenEstimator.estimate(text: content)
    }
}

extension AIMessage: CustomStringConvertible {
    public var description: String {
        "[\(role.rawValue.uppercased())] \(content)"
    }
}
