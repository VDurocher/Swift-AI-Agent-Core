import Foundation

/// Represents a single message in an AI conversation
public struct AIMessage: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let role: AIRole
    /// Text content of the message
    public let content: String
    public let timestamp: Date
    public var metadata: [String: String]?
    /// Optional image attachments for vision-capable models (GPT-4o, Claude 3+, Gemini)
    public let images: [AIImageContent]?
    /// Tool calls carried by assistant messages — enables correct agentic loop history encoding
    public let toolCalls: [AIToolCall]?
    /// When true, signals Anthropic to cache this content (prompt caching beta)
    public let cacheControl: Bool

    public init(
        id: String = UUID().uuidString,
        role: AIRole,
        content: String,
        timestamp: Date = Date(),
        metadata: [String: String]? = nil,
        images: [AIImageContent]? = nil,
        toolCalls: [AIToolCall]? = nil,
        cacheControl: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.metadata = metadata
        self.images = images
        self.toolCalls = toolCalls
        self.cacheControl = cacheControl
    }

    /// Create a user message, optionally with image attachments
    public static func user(_ content: String, images: [AIImageContent]? = nil) -> AIMessage {
        AIMessage(role: .user, content: content, images: images)
    }

    /// Create an assistant message
    public static func assistant(_ content: String) -> AIMessage {
        AIMessage(role: .assistant, content: content)
    }

    /// Create a system message
    /// - Parameter cached: Enable Anthropic prompt caching for this message's content
    public static func system(_ content: String, cached: Bool = false) -> AIMessage {
        AIMessage(role: .system, content: content, cacheControl: cached)
    }

    /// Estimated token count (rough approximation)
    public var estimatedTokens: Int {
        TokenEstimator.estimate(text: content)
    }
}

extension AIMessage: Equatable {
    public static func == (lhs: AIMessage, rhs: AIMessage) -> Bool {
        lhs.id == rhs.id
    }
}

extension AIMessage: CustomStringConvertible {
    public var description: String {
        "[\(role.rawValue.uppercased())] \(content)"
    }
}
