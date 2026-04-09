// The Swift Programming Language
// https://docs.swift.org/swift-book

/// SwiftAIAgentCore — Production-grade Swift package for multi-provider LLM agents
///
/// Supports OpenAI (GPT-4o, GPT-4.1), Anthropic (Claude 3–4), Google Gemini,
/// and local Ollama models — all behind a single `AIAgent` protocol.
///
/// # Features
/// - **Agentic ReAct loop**: `run(messages:tools:executor:maxSteps:)` automatically
///   executes tool calls until the model produces a final text response
/// - **Vision / multi-modal**: attach images (.url or .data) to any user message;
///   encoded correctly for GPT-4o, Claude 3+, and Gemini
/// - **Multi-provider**: OpenAI, Anthropic, Google Gemini, and Ollama (local)
/// - **Structured outputs**: `send<T>(messages:as:)` decodes JSON directly into any
///   `Codable` type; uses native JSON mode on OpenAI and Gemini
/// - **Prompt caching**: mark Anthropic messages with `cached: true` to enable
///   the prompt-caching beta and reduce latency + cost on repeated context
/// - **Streaming**: real-time responses via `AsyncThrowingStream` (SSE)
/// - **Reliability**: automatic retry with exponential backoff
/// - **Token management**: estimate and validate usage before requests
/// - **Swift 6.0**: strict concurrency — all types are `Sendable`, clients are `actor`
///
/// # Quick Start
/// ```swift
/// import SwiftAIAgentCore
///
/// // OpenAI
/// let agent = try AIAgentImplementation.gpt4o(apiKey: "sk-...")
///
/// // Anthropic
/// let claude = try AIAgentImplementation.claudeSonnet46(apiKey: "sk-ant-...")
///
/// // Gemini
/// let gemini = try AIAgentImplementation.gemini20Flash(apiKey: "AIza...")
///
/// // Ollama (no key required)
/// let local = try AIAgentImplementation.ollamaLlama32()
///
/// // Simple completion
/// let reply = try await agent.send(message: "Hello!")
///
/// // Structured output
/// struct Weather: Decodable, Sendable { let city: String; let temp: Double }
/// let weather = try await agent.send(messages: [...], as: Weather.self)
///
/// // Agentic loop with tools
/// let answer = try await agent.run(
///     messages: [.user("What files are in /tmp?")],
///     tools: [listFilesTool],
///     executor: { call in try await runTool(call) },
///     maxSteps: 10
/// )
///
/// // Vision
/// let image = AIImageContent.data(jpegData, mimeType: "image/jpeg")
/// let caption = try await agent.send(messages: [.user("Describe this", images: [image])])
/// ```
///
/// # Architecture
/// - **Core**: domain models, protocols, error types, and business logic
/// - **Network**: actor-based API clients per provider with streaming SSE support
/// - **Persistence**: SwiftData-backed conversation history (iOS 17+ / macOS 14+)
/// - **Utils**: token estimation and validation

// Re-export all public types
@_exported import struct Foundation.Date
@_exported import struct Foundation.TimeInterval
@_exported import struct Foundation.UUID

// Exports explicites des types de tool calling pour les consommateurs du package
// AITool, AIToolParameters, AIToolProperty — définition des outils disponibles
// AIToolCall — appel d'outil retourné par le modèle
// AIToolResult — résultat d'exécution fourni par l'application
// AIMessageWithTools — réponse unifiée texte + appels d'outils
