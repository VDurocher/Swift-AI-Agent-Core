import Foundation

/// Supported AI model providers
public enum AIProvider: String, Codable, Sendable {
    case openai
    case anthropic
    case gemini
    /// Local inference via Ollama (requires Ollama running at localhost:11434)
    case ollama

    public var baseURL: String {
        switch self {
        case .openai:
            return "https://api.openai.com/v1"
        case .anthropic:
            return "https://api.anthropic.com/v1"
        case .gemini:
            return "https://generativelanguage.googleapis.com/v1beta"
        case .ollama:
            // Ollama exposes an OpenAI-compatible endpoint by default
            return "http://localhost:11434/v1"
        }
    }
}

/// AI model configuration
public struct AIModel: Codable, Sendable, Hashable {
    public let provider: AIProvider
    public let name: String
    public let maxTokens: Int
    public let supportsStreaming: Bool
    /// Whether the model can process image inputs
    public let supportsVision: Bool

    public init(
        provider: AIProvider,
        name: String,
        maxTokens: Int,
        supportsStreaming: Bool = true,
        supportsVision: Bool = false
    ) {
        self.provider = provider
        self.name = name
        self.maxTokens = maxTokens
        self.supportsStreaming = supportsStreaming
        self.supportsVision = supportsVision
    }

    // MARK: - OpenAI Models

    public static let gpt4 = AIModel(provider: .openai, name: "gpt-4", maxTokens: 8192)
    public static let gpt4Turbo = AIModel(provider: .openai, name: "gpt-4-turbo", maxTokens: 128000, supportsVision: true)
    public static let gpt35Turbo = AIModel(provider: .openai, name: "gpt-3.5-turbo", maxTokens: 16385)
    public static let gpt4o = AIModel(provider: .openai, name: "gpt-4o", maxTokens: 128000, supportsVision: true)
    public static let gpt4oMini = AIModel(provider: .openai, name: "gpt-4o-mini", maxTokens: 128000, supportsVision: true)
    public static let gpt41 = AIModel(provider: .openai, name: "gpt-4.1", maxTokens: 1047576, supportsVision: true)
    public static let gpt41Mini = AIModel(provider: .openai, name: "gpt-4.1-mini", maxTokens: 1047576, supportsVision: true)

    // MARK: - Anthropic Models (all Claude 3+ support vision)

    public static let claude3Opus = AIModel(provider: .anthropic, name: "claude-3-opus-20240229", maxTokens: 200000, supportsVision: true)
    public static let claude3Sonnet = AIModel(provider: .anthropic, name: "claude-3-sonnet-20240229", maxTokens: 200000, supportsVision: true)
    public static let claude3Haiku = AIModel(provider: .anthropic, name: "claude-3-haiku-20240307", maxTokens: 200000, supportsVision: true)
    public static let claude35Sonnet = AIModel(provider: .anthropic, name: "claude-3-5-sonnet-20241022", maxTokens: 200000, supportsVision: true)
    public static let claude35Haiku = AIModel(provider: .anthropic, name: "claude-3-5-haiku-20241022", maxTokens: 200000, supportsVision: true)
    public static let claude37Sonnet = AIModel(provider: .anthropic, name: "claude-3-7-sonnet-20250219", maxTokens: 200000, supportsVision: true)
    public static let claudeSonnet46 = AIModel(provider: .anthropic, name: "claude-sonnet-4-6", maxTokens: 200000, supportsVision: true)
    public static let claudeOpus46 = AIModel(provider: .anthropic, name: "claude-opus-4-6", maxTokens: 200000, supportsVision: true)
    public static let claudeHaiku45 = AIModel(provider: .anthropic, name: "claude-haiku-4-5-20251001", maxTokens: 200000, supportsVision: true)

    // MARK: - Google Gemini Models

    /// Gemini 2.0 Flash — fast and efficient, 1M context, vision support
    public static let gemini20Flash = AIModel(provider: .gemini, name: "gemini-2.0-flash", maxTokens: 1048576, supportsVision: true)
    /// Gemini 2.0 Flash Lite — most cost-efficient, 1M context
    public static let gemini20FlashLite = AIModel(provider: .gemini, name: "gemini-2.0-flash-lite", maxTokens: 1048576, supportsVision: true)
    /// Gemini 1.5 Pro — 2M context window, vision support
    public static let gemini15Pro = AIModel(provider: .gemini, name: "gemini-1.5-pro", maxTokens: 2097152, supportsVision: true)
    /// Gemini 1.5 Flash — fast and cost-efficient, 1M context
    public static let gemini15Flash = AIModel(provider: .gemini, name: "gemini-1.5-flash", maxTokens: 1048576, supportsVision: true)

    // MARK: - Ollama (local models — require Ollama running at localhost:11434)

    public static let ollamaLlama32 = AIModel(provider: .ollama, name: "llama3.2", maxTokens: 128000)
    public static let ollamaLlama31 = AIModel(provider: .ollama, name: "llama3.1", maxTokens: 128000)
    public static let ollamaMistral = AIModel(provider: .ollama, name: "mistral", maxTokens: 32768)
    public static let ollamaPhi4 = AIModel(provider: .ollama, name: "phi4", maxTokens: 16384)

    /// Custom Ollama model — any model name installed on the local Ollama instance
    public static func ollamaCustom(name: String, maxTokens: Int = 32768) -> AIModel {
        AIModel(provider: .ollama, name: name, maxTokens: maxTokens)
    }
}
