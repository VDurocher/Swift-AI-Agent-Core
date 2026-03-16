import Foundation

/// Role of a message in the conversation
public enum AIRole: String, Codable, Sendable, Hashable {
    case system
    case user
    case assistant
    case function
    case tool

    /// OpenAI-compatible role name
    public var openAIName: String {
        rawValue
    }

    /// Anthropic-compatible role name
    public var anthropicName: String {
        switch self {
        case .system: return "system"
        case .user: return "user"
        case .assistant: return "assistant"
        case .function, .tool: return "assistant"
        }
    }
}
