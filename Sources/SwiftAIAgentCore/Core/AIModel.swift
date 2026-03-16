import Foundation

/// Supported AI model providers and their models
public enum AIProvider: String, Codable, Sendable {
    case openai
    case anthropic

    public var baseURL: String {
        switch self {
        case .openai:
            return "https://api.openai.com/v1"
        case .anthropic:
            return "https://api.anthropic.com/v1"
        }
    }
}

/// AI model configuration
public struct AIModel: Codable, Sendable, Hashable {
    public let provider: AIProvider
    public let name: String
    public let maxTokens: Int
    public let supportsStreaming: Bool

    public init(
        provider: AIProvider,
        name: String,
        maxTokens: Int,
        supportsStreaming: Bool = true
    ) {
        self.provider = provider
        self.name = name
        self.maxTokens = maxTokens
        self.supportsStreaming = supportsStreaming
    }

    // MARK: - OpenAI Models

    public static let gpt4 = AIModel(
        provider: .openai,
        name: "gpt-4",
        maxTokens: 8192
    )

    public static let gpt4Turbo = AIModel(
        provider: .openai,
        name: "gpt-4-turbo-preview",
        maxTokens: 128000
    )

    public static let gpt35Turbo = AIModel(
        provider: .openai,
        name: "gpt-3.5-turbo",
        maxTokens: 16385
    )

    // MARK: - Anthropic Models

    public static let claude3Opus = AIModel(
        provider: .anthropic,
        name: "claude-3-opus-20240229",
        maxTokens: 200000
    )

    public static let claude3Sonnet = AIModel(
        provider: .anthropic,
        name: "claude-3-sonnet-20240229",
        maxTokens: 200000
    )

    public static let claude3Haiku = AIModel(
        provider: .anthropic,
        name: "claude-3-haiku-20240307",
        maxTokens: 200000
    )
}
