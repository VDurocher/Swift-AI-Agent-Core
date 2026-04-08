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

    /// GPT-4 — 8k context
    public static let gpt4 = AIModel(
        provider: .openai,
        name: "gpt-4",
        maxTokens: 8192
    )

    /// GPT-4 Turbo — 128k context
    public static let gpt4Turbo = AIModel(
        provider: .openai,
        name: "gpt-4-turbo",
        maxTokens: 128000
    )

    /// GPT-3.5 Turbo — fast and cost-efficient, 16k context
    public static let gpt35Turbo = AIModel(
        provider: .openai,
        name: "gpt-3.5-turbo",
        maxTokens: 16385
    )

    /// GPT-4o — OpenAI flagship multimodal model, 128k context
    public static let gpt4o = AIModel(
        provider: .openai,
        name: "gpt-4o",
        maxTokens: 128000
    )

    /// GPT-4o Mini — lightweight and fast variant of GPT-4o, 128k context
    public static let gpt4oMini = AIModel(
        provider: .openai,
        name: "gpt-4o-mini",
        maxTokens: 128000
    )

    // MARK: - Anthropic Models

    /// Claude 3 Opus — most capable Claude 3 model, 200k context
    public static let claude3Opus = AIModel(
        provider: .anthropic,
        name: "claude-3-opus-20240229",
        maxTokens: 200000
    )

    /// Claude 3 Sonnet — balanced performance and speed, 200k context
    public static let claude3Sonnet = AIModel(
        provider: .anthropic,
        name: "claude-3-sonnet-20240229",
        maxTokens: 200000
    )

    /// Claude 3 Haiku — fastest and most compact Claude 3 model, 200k context
    public static let claude3Haiku = AIModel(
        provider: .anthropic,
        name: "claude-3-haiku-20240307",
        maxTokens: 200000
    )

    /// Claude 3.5 Sonnet — high-performance Anthropic model, 200k context
    public static let claude35Sonnet = AIModel(
        provider: .anthropic,
        name: "claude-3-5-sonnet-20241022",
        maxTokens: 200000
    )

    /// Claude 3.5 Haiku — fast and cost-efficient Anthropic model, 200k context
    public static let claude35Haiku = AIModel(
        provider: .anthropic,
        name: "claude-3-5-haiku-20241022",
        maxTokens: 200000
    )

    /// Claude Sonnet 4.6 — latest Sonnet model, 200k context
    public static let claudeSonnet46 = AIModel(
        provider: .anthropic,
        name: "claude-sonnet-4-6",
        maxTokens: 200000
    )

    /// Claude Opus 4.6 — most capable Claude 4 model, 200k context
    public static let claudeOpus46 = AIModel(
        provider: .anthropic,
        name: "claude-opus-4-6",
        maxTokens: 200000
    )

    /// Claude Haiku 4.5 — fastest and most cost-efficient Claude 4 model, 200k context
    public static let claudeHaiku45 = AIModel(
        provider: .anthropic,
        name: "claude-haiku-4-5-20251001",
        maxTokens: 200000
    )

    // MARK: - OpenAI Latest Models

    /// GPT-4.1 — flagship model with 1M context (April 2025)
    public static let gpt41 = AIModel(
        provider: .openai,
        name: "gpt-4.1",
        maxTokens: 1047576
    )

    /// GPT-4.1 Mini — lightweight variant with 1M context
    public static let gpt41Mini = AIModel(
        provider: .openai,
        name: "gpt-4.1-mini",
        maxTokens: 1047576
    )

    // MARK: - Anthropic Latest Models

    /// Claude 3.7 Sonnet — extended thinking, 200k context (February 2025)
    public static let claude37Sonnet = AIModel(
        provider: .anthropic,
        name: "claude-3-7-sonnet-20250219",
        maxTokens: 200000
    )
}
