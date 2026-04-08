# Changelog

All notable changes to SwiftAIAgentCore are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

### Added
- GPT-4.1 and GPT-4.1 Mini models (1M context, OpenAI April 2025)
- Claude 3.7 Sonnet model with extended thinking support (Anthropic February 2025)

### Changed
- Split `AnthropicClient.swift` into `AnthropicClient.swift` + `AnthropicClientModels.swift`

---

## [1.0.0] — 2026-04-08

### Added
- **OpenAI support**: GPT-4, GPT-4 Turbo, GPT-3.5 Turbo, GPT-4o, GPT-4o Mini
- **Anthropic support**: Claude 3 (Haiku/Sonnet/Opus), Claude 3.5 (Haiku/Sonnet), Claude 4 (Haiku 4.5, Sonnet 4.6, Opus 4.6)
- Streaming responses via `AsyncThrowingStream`
- Automatic retry with exponential backoff (`RetryPolicy`)
- Token estimation and validation (`TokenEstimator`)
- Function calling / tool use for both providers
- SwiftData persistence layer (`HistoryManager`, `ConversationRecord`, `MessageRecord`)
- SwiftUI history views (`HistoryView`, `ConversationDetailView`)
- 13 convenience initializers (`gpt4()`, `claude3Sonnet()`, etc.)
- Swift 6.0 strict concurrency — fully `Sendable`, `actor`-based
- Zero external dependencies
- CI on macOS 15 (Swift 6) via GitHub Actions

[Unreleased]: https://github.com/VDurocher/Swift-AI-Agent-Core/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/VDurocher/Swift-AI-Agent-Core/releases/tag/v1.0.0
