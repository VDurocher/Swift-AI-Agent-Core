# Changelog

All notable changes to SwiftAIAgentCore will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] — 2025-05-01

### Added
- **Agentic ReAct loop** — `run(messages:tools:executor:maxSteps:)` executes tool calls automatically until the model produces a final text response; throws `AIError.agentLoopExceeded` when `maxSteps` is reached
- **Vision / multi-modal** — `AIImageContent` supports `.url` and `.data(mimeType:)` attachments; encoded correctly for GPT-4o, Claude 3+, and Gemini
- **Google Gemini** — full support for `generateContent` and `streamGenerateContent`, including tool use, JSON mode, and vision
- **Ollama (local)** — local inference via `http://localhost:11434/v1` (OpenAI-compatible); no API key required
- **Structured outputs** — `send<T: Decodable & Sendable>(messages:as:)` decodes JSON directly into any `Codable` type; native JSON mode on OpenAI and Gemini
- **Prompt caching** — Anthropic prompt-caching beta: mark messages with `cached: true` to add `cache_control: {type: "ephemeral"}` and the required beta header
- New models: GPT-4.1, GPT-4.1 Mini, Claude Sonnet 4.6, Claude Opus 4.6, Claude Haiku 4.5, Claude 3.7 Sonnet, Gemini 2.0 Flash / Lite, Gemini 1.5 Pro / Flash, Ollama Llama 3.2 / 3.1 / Mistral / Phi-4

### Fixed
- Gemini API wire format for agentic tool metadata (`tool_call_id` and `tool_name` fields)
- SSE stream buffer size limit to prevent memory accumulation on long streams
- Stream cancellation propagation when the caller cancels the enclosing `Task`
- Input validation: API key, temperature range, and `maxResponseTokens` bounds checked before any network call

### Security
- Added bounds checking on SSE line buffer to prevent unbounded memory growth
- `AIAgentImplementation` is an `actor` — all mutable state is isolated, no `@unchecked Sendable` workarounds

---

## [1.0.0] — 2025-03-15

### Added
- `AIAgent` protocol with `send(message:)`, `send(messages:)`, `stream(message:)`, `stream(messages:)`, and `estimateTokens(for:)` default implementations
- `AIAgentImplementation` — concrete `actor` implementation routing to the correct provider client
- **OpenAI** — `OpenAIClient` supporting Chat Completions, streaming SSE, tool use, and native `json_object` mode
- **Anthropic** — `AnthropicClient` supporting Messages API, streaming SSE, and tool use
- Function calling (tool use) — `AITool`, `AIToolParameters`, `AIToolProperty`, `AIToolCall`, `AIToolResult`, `AIMessageWithTools`
- **SwiftData persistence** (iOS 17+ / macOS 14+) — `HistoryManager` (`@ModelActor`), `ConversationRecord`, `MessageRecord`
- **SwiftUI history views** — `HistoryView` (conversation list with delete) and `ConversationDetailView`
- `TokenEstimator` — estimate, validate, and truncate messages against model token limits
- `AIError` — exhaustive typed error enum conforming to `LocalizedError` with `isRecoverable` flag
- `RetryPolicy` — configurable exponential backoff with `.default`, `.none`, and `.aggressive` presets
- Convenience initializers for GPT-4, GPT-4 Turbo, GPT-3.5 Turbo, GPT-4o, GPT-4o Mini; Claude 3 Haiku / Sonnet / Opus; Claude 3.5 Haiku / Sonnet
- GitHub Actions CI: macOS (Xcode 15.4 / 16.0) + Linux (Swift 6.0 Docker image) + SwiftLint
- Zero external dependencies — pure Swift, Foundation only

---

[1.1.0]: https://github.com/VDurocher/Swift-AI-Agent-Core/compare/1.0.0...1.1.0
[1.0.0]: https://github.com/VDurocher/Swift-AI-Agent-Core/releases/tag/1.0.0
