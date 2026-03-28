# Swift AI Agent Core

> Production-grade Swift package for integrating LLM agents into iOS, macOS, watchOS, and tvOS apps.

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20watchOS%20%7C%20tvOS-blue.svg)](https://developer.apple.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![SPM Compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)

**SwiftAIAgentCore** integrates OpenAI and Anthropic language models into Apple platform apps. Built with Swift 6.0 strict concurrency, clean architecture, and local persistence via SwiftData.

---

## Features

- **Streaming responses** — real-time chunks via `AsyncThrowingStream`
- **Automatic retry** — exponential backoff with configurable policies
- **Token management** — estimate and validate token usage before sending requests
- **Function calling** — tool use API compatible with both OpenAI and Anthropic formats
- **Local persistence** — conversation history via SwiftData (iOS 17+ / macOS 14+)
- **Typed errors** — exhaustive `AIError` enum covering all failure scenarios
- **Swift 6.0 concurrency** — fully `Sendable` types, `actor`-based implementation
- **Zero dependencies** — pure Swift, no external packages

## Supported Models

| Provider | Models |
|----------|--------|
| OpenAI | GPT-4, GPT-4 Turbo, GPT-3.5 Turbo, GPT-4o, GPT-4o Mini |
| Anthropic | Claude 3 Opus, Claude 3 Sonnet, Claude 3 Haiku, Claude 3.5 Sonnet, Claude 3.5 Haiku, Claude Sonnet 4.6 |

---

## Requirements

- iOS 16.0+ / macOS 13.0+ / watchOS 9.0+ / tvOS 16.0+
- Swift 6.0+
- Xcode 16.0+

> The persistence layer (`HistoryManager`, `HistoryView`) requires iOS 17.0+ / macOS 14.0+ / watchOS 10.0+ / tvOS 17.0+. All other functionality works from the base deployment targets.

---

## Installation

### Swift Package Manager

Add SwiftAIAgentCore to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/VDurocher/Swift-AI-Agent-Core.git", from: "1.0.0")
]
```

Or add it via Xcode:
1. File > Add Package Dependencies
2. Enter: `https://github.com/VDurocher/Swift-AI-Agent-Core`
3. Select version and add to your target

---

## Quick Start

### Basic Usage

```swift
import SwiftAIAgentCore

// Create an agent with a convenience initializer
let agent = try AIAgentImplementation.gpt4(apiKey: "your-openai-api-key")

// Send a single message — returns the response as a plain String
let response = try await agent.send(message: "Explain Swift concurrency in one sentence.")
print(response)
```

### Streaming Responses

```swift
for try await chunk in agent.stream(message: "Write a haiku about coding") {
    print(chunk, terminator: "")
}
```

### Multi-Turn Conversations

```swift
let conversation: [AIMessage] = [
    .system("You are a Swift expert."),
    .user("What is a protocol?"),
]

// Returns an AIMessage with role .assistant
let response = try await agent.send(messages: conversation)
print(response.content)
```

### Anthropic (Claude)

```swift
let claudeAgent = try AIAgentImplementation.claude3Opus(apiKey: "your-anthropic-api-key")
let response = try await claudeAgent.send(message: "Summarize the Swift concurrency model.")
print(response)
```

---

## SwiftUI Integration

`AIMessage` conforms to `Identifiable`, so it works directly with `ForEach`:

```swift
import SwiftUI
import SwiftAIAgentCore

struct ChatView: View {
    @State private var messages: [AIMessage] = []
    @State private var input = ""

    let agent: any AIAgent

    var body: some View {
        VStack {
            ScrollView {
                ForEach(messages) { message in
                    HStack {
                        if message.role == .user { Spacer() }
                        Text(message.content)
                            .padding()
                            .background(message.role == .user ? Color.blue : Color.gray)
                            .cornerRadius(10)
                        if message.role == .assistant { Spacer() }
                    }
                }
            }
            HStack {
                TextField("Message...", text: $input)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Send") {
                    Task { await sendMessage() }
                }
            }
            .padding()
        }
    }

    func sendMessage() async {
        guard !input.isEmpty else { return }
        let userMessage = AIMessage.user(input)
        messages.append(userMessage)
        input = ""
        do {
            let response = try await agent.send(messages: messages)
            messages.append(response)
        } catch {
            // Handle AIError cases
        }
    }
}
```

---

## Local Persistence

The persistence layer is powered by **SwiftData** and stores all data on-device. It requires iOS 17.0+ / macOS 14.0+ / watchOS 10.0+ / tvOS 17.0+.

### Setup

```swift
import SwiftUI
import SwiftData
import SwiftAIAgentCore

// 1. Create the ModelContainer once at app startup
let schema = Schema([ConversationRecord.self, MessageRecord.self])
let container = try ModelContainer(for: schema)

// 2. Create the HistoryManager
let historyManager = HistoryManager(modelContainer: container)

// 3. Initialize the agent with history persistence
let agent = try AIAgentImplementation(
    configuration: AIConfiguration(model: .gpt4Turbo, apiKey: "your-api-key"),
    historyManager: historyManager
)

// Every call to send() now auto-saves the conversation locally
let response = try await agent.send(message: "Hello!")
```

### SwiftUI History View

The package provides a ready-to-use `HistoryView` that lists conversations with delete support:

```swift
@main
struct MyApp: App {
    let container = try! ModelContainer(for: ConversationRecord.self, MessageRecord.self)

    var body: some Scene {
        WindowGroup {
            HistoryView()
                .modelContainer(container)
        }
    }
}
```

### Resume Previous Context

```swift
// Load the last 20 messages from the most recent conversation
let previousMessages = try await agent.loadPreviousContext(limit: 20)

// Append new user input and continue
let messages = previousMessages + [.user("Continue from where we left off")]
let response = try await agent.send(messages: messages)
```

---

## Function Calling (Tool Use)

SwiftAIAgentCore supports the tool use API for both OpenAI and Anthropic. Define tools with a JSON Schema description, send them alongside messages, and handle the model's tool calls in your app:

```swift
// 1. Define a tool
let weatherTool = AITool(
    name: "get_weather",
    description: "Returns the current weather for a city",
    parameters: AIToolParameters(
        properties: [
            "city": AIToolProperty(type: "string", description: "City name"),
            "unit": AIToolProperty(
                type: "string",
                description: "Temperature unit",
                enumValues: ["celsius", "fahrenheit"]
            )
        ],
        required: ["city"]
    )
)

// 2. Send with tools — the model may request a tool call
let result = try await agent.send(messages: conversation, tools: [weatherTool])

// 3. Check if the model wants to call a tool
if result.requiresToolExecution {
    for toolCall in result.toolCalls {
        let args = toolCall.decodeArguments() // [String: Any]?
        // Execute the tool in your app, then send the result back
        let toolResult = AIToolResult(toolCallId: toolCall.id, content: "22°C, sunny")
        let finalResponse = try await agent.send(messages: conversation, toolResults: [toolResult])
        print(finalResponse.message.content)
    }
}
```

---

## API Reference

### `AIAgent` Protocol

```swift
public protocol AIAgent: Sendable {
    var configuration: AIConfiguration { get }

    func send(message: String) async throws -> String
    func send(messages: [AIMessage]) async throws -> AIMessage
    func stream(message: String) -> AsyncThrowingStream<String, Error>
    func stream(messages: [AIMessage]) -> AsyncThrowingStream<String, Error>
    func estimateTokens(for messages: [AIMessage]) -> Int
    func send(messages: [AIMessage], tools: [AITool]) async throws -> AIMessageWithTools
    func send(messages: [AIMessage], toolResults: [AIToolResult]) async throws -> AIMessageWithTools
}
```

Default implementations are provided for `send(message:)`, `stream(message:)`, `estimateTokens(for:)`, and both tool-related methods.

### `AIConfiguration`

```swift
let config = AIConfiguration(
    model: .gpt4Turbo,
    apiKey: "your-api-key",
    temperature: 0.7,          // 0.0–2.0
    maxResponseTokens: 2000,
    timeout: 30,
    retryPolicy: .default
)
let agent = try AIAgentImplementation(configuration: config)
```

### Convenience Initializers

```swift
// OpenAI
AIAgentImplementation.gpt4(apiKey:)
AIAgentImplementation.gpt4Turbo(apiKey:)
AIAgentImplementation.gpt4o(apiKey:)
AIAgentImplementation.gpt4oMini(apiKey:)

// Anthropic
AIAgentImplementation.claude3Opus(apiKey:)
AIAgentImplementation.claude3Sonnet(apiKey:)
AIAgentImplementation.claude35Sonnet(apiKey:)
AIAgentImplementation.claudeSonnet46(apiKey:)
```

### Retry Policies

```swift
RetryPolicy.default      // 3 retries, exponential backoff (1s → 60s)
RetryPolicy.none         // No retries
RetryPolicy.aggressive   // 5 retries, shorter delays (0.5s → 30s)

// Custom
RetryPolicy(maxRetries: 3, initialDelay: 1.0, maxDelay: 60.0, multiplier: 2.0)
```

### Token Management

```swift
// Estimate token count for a message array
let tokens = TokenEstimator.estimate(messages: messages)

// Validate against model limits (throws AIError.tokenLimitExceeded if over limit)
try TokenEstimator.validate(messages: messages, model: .gpt4, maxResponseTokens: 1000)

// Truncate to fit within a limit, preserving system messages
let truncated = TokenEstimator.truncate(messages: messages, limit: 2000, keepSystemMessages: true)
```

### Error Handling

```swift
do {
    let response = try await agent.send(message: "Hello")
} catch let error as AIError {
    switch error {
    case .invalidAPIKey:
        // Invalid or missing API key
    case .rateLimit(let retryAfter):
        // Rate limited — retryAfter is TimeInterval? (seconds to wait)
    case .tokenLimitExceeded(let current, let max):
        // current and max are Int (token counts)
    case .networkError(let underlying):
        // Underlying URLSession or transport error
    case .timeout:
        // Request exceeded the configured timeout
    case .invalidResponse(let statusCode, let message):
        // Non-2xx HTTP response
    case .streamingError(let reason):
        // Error during streaming (including model not supporting streaming)
    case .cancelled:
        // Task was cancelled
    case .decodingError, .invalidContext, .unknown:
        break
    }

    if error.isRecoverable {
        // rateLimit, networkError, and timeout are recoverable
        // Retry is handled automatically by the configured RetryPolicy
    }
}
```

---

## Architecture

```
Sources/SwiftAIAgentCore/
├── Core/
│   ├── AIAgentProtocol.swift       — AIAgent protocol
│   ├── AIMessage.swift             — Message model (user / assistant / system)
│   ├── AIRole.swift                — Role enumeration
│   ├── AIModel.swift               — Model configurations (GPT-4, Claude, etc.)
│   ├── AIConfiguration.swift       — Agent configuration and retry policies
│   ├── AIError.swift               — Typed error enum
│   ├── AITool.swift                — Tool (function) definition for tool use
│   └── AIToolCall.swift            — Tool call / result / response types
│
├── Network/
│   ├── NetworkClient.swift         — Base HTTP client with retry logic
│   ├── OpenAIClient.swift          — OpenAI Chat Completions API
│   ├── AnthropicClient.swift       — Anthropic Messages API
│   └── AIAgentImplementation.swift — Concrete actor conforming to AIAgent
│
├── Persistence/                    — iOS 17+ / macOS 14+ only
│   ├── ConversationRecord.swift    — SwiftData model for conversations
│   ├── MessageRecord.swift         — SwiftData model for messages
│   └── HistoryManager.swift        — @ModelActor — thread-safe history operations
│
├── UI/                             — iOS 17+ / macOS 14+ only
│   ├── HistoryView.swift           — Conversation list with delete support
│   └── ConversationDetailView.swift — Message-level view
│
└── Utils/
    └── TokenEstimator.swift        — Token counting and truncation
```

`AIAgentImplementation` is declared as `actor`, guaranteeing thread-safe access to its internal clients. All calls to its methods require `await`.

---

## Testing

```bash
swift test
```

### Mocking

`AIAgent` is a protocol — implement it to create test doubles. Because `AIAgentImplementation` is an `actor`, mocks must be `Sendable`. The protocol includes two tool-use methods; provide at least stub implementations:

```swift
struct MockAIAgent: AIAgent {
    let configuration: AIConfiguration

    func send(messages: [AIMessage]) async throws -> AIMessage {
        .assistant("Mocked response")
    }

    func stream(messages: [AIMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield("Mocked stream")
            continuation.finish()
        }
    }

    func send(messages: [AIMessage], tools: [AITool]) async throws -> AIMessageWithTools {
        AIMessageWithTools(message: .assistant("Mocked tool response"))
    }

    func send(messages: [AIMessage], toolResults: [AIToolResult]) async throws -> AIMessageWithTools {
        AIMessageWithTools(message: .assistant("Mocked tool result response"))
    }
}
```

---

## Examples

The [Examples](Examples/) directory contains:

- **BasicExample.swift** — single message, streaming, and multi-turn conversation
- **AdvancedExample.swift** — token management, retry handling, production patterns
- **ChatApp/** — a complete SwiftUI macOS chat application using the package

Run the basic example:

```bash
cd Examples
export OPENAI_API_KEY="your-key"
swift BasicExample.swift
```

---

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/your-feature`)
3. Commit your changes (`git commit -m 'feat: add your feature'`)
4. Push to the branch (`git push origin feature/your-feature`)
5. Open a Pull Request

```bash
git clone https://github.com/VDurocher/Swift-AI-Agent-Core.git
cd Swift-AI-Agent-Core
swift build
swift test
```

---

## License

MIT — see [LICENSE](LICENSE).

---

[@VDurocher](https://github.com/VDurocher)
