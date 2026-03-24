// The Swift Programming Language
// https://docs.swift.org/swift-book

/// SwiftAIAgentCore - Professional Swift package for integrating LLM agents into iOS apps
///
/// This package provides production-grade tools for integrating AI language models
/// (OpenAI GPT, Anthropic Claude) into iOS, macOS, watchOS, and tvOS applications.
///
/// # Features
/// - **Streaming Support**: Real-time AI responses using AsyncThrowingStream
/// - **Reliability Layer**: Automatic retry mechanism with exponential backoff
/// - **Error Handling**: Comprehensive error types for all failure scenarios
/// - **Token Management**: Estimate and validate token usage before requests
/// - **Clean Architecture**: Separation between Network, Domain, and Interface layers
/// - **Swift 6.0**: Full concurrency support with Sendable types
///
/// # Quick Start
/// ```swift
/// import SwiftAIAgentCore
///
/// // Create an agent
/// let agent = try AIAgentImplementation.gpt4(apiKey: "your-api-key")
///
/// // Send a message
/// let response = try await agent.send(message: "Hello!")
/// print(response)
///
/// // Stream a response
/// for try await chunk in agent.stream(message: "Tell me a story") {
///     print(chunk, terminator: "")
/// }
/// ```
///
/// # Architecture
/// - **Core**: Domain models, protocols, and business logic
/// - **Network**: API clients for OpenAI and Anthropic with streaming support
/// - **Utils**: Token estimation and utility functions

// Re-export all public types
@_exported import struct Foundation.Date
@_exported import struct Foundation.TimeInterval
@_exported import struct Foundation.UUID

// Exports explicites des types de tool calling pour les consommateurs du package
// AITool, AIToolParameters, AIToolProperty — définition des outils disponibles
// AIToolCall — appel d'outil retourné par le modèle
// AIToolResult — résultat d'exécution fourni par l'application
// AIMessageWithTools — réponse unifiée texte + appels d'outils
