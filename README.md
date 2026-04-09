# Swift AI Agent Core

> Production-grade Swift package for integrating multi-provider LLM agents into iOS, macOS, watchOS, and tvOS apps.

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20watchOS%20%7C%20tvOS-blue.svg)](https://developer.apple.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![SPM Compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)

**SwiftAIAgentCore** is a unified Swift interface for OpenAI, Anthropic Claude, Google Gemini, and local Ollama models. Built with Swift 6.0 strict concurrency, a clean protocol-oriented architecture, and local persistence via SwiftData.

---

## Features

- **Agentic ReAct loop** — `run(messages:tools:executor:maxSteps:)` automatically executes tool calls in a loop until the model produces a final text response
- **Vision / multi-modal** — attach images (URL or raw bytes) to any user message; encoded correctly for GPT-4o, Claude 3+, and Gemini
- **Multi-provider** — OpenAI, Anthropic Claude, Google Gemini, and local Ollama behind one `AIAgent` protocol
- **Structured outputs** — `send<T>(messages:as:)` decodes JSON directly into any `Codable` type, with native JSON mode on OpenAI and Gemini
- **Prompt caching** — mark Anthropic messages with `cached: true` to enable the prompt-caching beta and reduce latency and cost on repeated context
- **Streaming responses** — real-time chunks via `AsyncThrowingStream` (SSE)
- **Automatic retry** — exponential backoff with configurable policies
- **Token management** — estimate and validate usage before sending requests
- **Local persistence** — conversation history via SwiftData (iOS 17+ / macOS 14+)
- **Typed errors** — exhaustive `AIError` enum covering all failure scenarios
- **Swift 6.0 concurrency** — fully `Sendable` types, `actor`-based implementation
- **Zero dependencies** — pure Swift, no external packages

## Supported Models

| Provider | Models |
|----------|--------|
| OpenAI | GPT-4, GPT-4 Turbo, GPT-3.5 Turbo, GPT-4o, GPT-4o Mini, GPT-4.1, GPT-4.1 Mini |
| Anthropic | Claude 3 Haiku/Sonnet/Opus, Claude 3.5 Haiku/Sonnet, Claude 3.7 Sonnet, Claude Haiku 4.5, Claude Sonnet 4.6, Claude Opus 4.6 |
| Google | Gemini 2.0 Flash, Gemini 2.0 Flash Lite, Gemini 1.5 Pro, Gemini 1.5 Flash |
| Ollama (local) | Llama 3.2, Llama 3.1, Mistral, Phi-4, any custom model |

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

// OpenAI
let agent = try AIAgentImplementation.gpt4o(apiKey: "sk-...")

// Anthropic Claude
let claude = try AIAgentImplementation.claudeSonnet46(apiKey: "sk-ant-...")

// Google Gemini
let gemini = try AIAgentImplementation.gemini20Flash(apiKey: "AIza...")

// Ollama (local — no API key needed)
let local = try AIAgentImplementation.ollamaLlama32()

// Send a message
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

let response = try await agent.send(messages: conversation)
print(response.content)
```

---

## Agentic Loop (ReAct Pattern)

`run(messages:tools:executor:maxSteps:)` automatically calls tools and feeds results back until the model produces a final text answer — no manual loop needed.

```swift
let answer = try await agent.run(
    messages: [.user("What is the current temperature in Paris?")],
    tools: [weatherTool],
    executor: { call in
        // Execute the tool and return the result as a String
        let args = call.decodeArguments()
        let city = args?["city"] as? String ?? "Paris"
        return "22°C, sunny"
    },
    maxSteps: 10
)
print(answer.content)
```

The loop appends tool calls and results to the conversation history, then sends the enriched history back to the model — repeating until `requiresToolExecution` is false or `maxSteps` is reached (throws `AIError.agentLoopExceeded`).

---

## Vision (Multi-Modal)

Attach images to any user message. Supported on GPT-4o, Claude 3+, and Gemini.

```swift
// From a URL
let image = AIImageContent.url(URL(string: "https://example.com/photo.jpg")!)

// From raw bytes (e.g. UIImage → Data)
let jpegData = uiImage.jpegData(compressionQuality: 0.8)!
let image = AIImageContent.data(jpegData, mimeType: "image/jpeg")

// Attach to a message
let response = try await agent.send(messages: [
    .user("What is in this image?", images: [image])
])
print(response.content)
```

---

## Google Gemini

```swift
let gemini = try AIAgentImplementation.gemini20Flash(apiKey: "AIza...")

// Standard completion
let reply = try await gemini.send(message: "Hello from Gemini!")

// Streaming
for try await chunk in gemini.stream(message: "Tell me a story") {
    print(chunk, terminator: "")
}

// Tool use
let result = try await gemini.send(messages: messages, tools: [myTool])
```

All Gemini models support vision, tool use, streaming, JSON mode, and the agentic loop.

---

## Ollama (Local Models)

Run models locally with [Ollama](https://ollama.com) — no API key required.

```swift
// Predefined models
let llama = try AIAgentImplementation.ollamaLlama32()
let mistral = try AIAgentImplementation.ollamaMistral()

// Any custom model
let custom = try AIAgentImplementation.ollamaCustom(name: "deepseek-r1:7b")

let reply = try await llama.send(message: "Hello!")
```

Ollama uses the OpenAI-compatible endpoint at `http://localhost:11434/v1` — same wire format, zero extra code.

---

## Structured Outputs

Decode the model's JSON response directly into a `Codable` type. Uses native JSON mode on OpenAI and Gemini; injects a system instruction for Anthropic.

```swift
struct Product: Decodable, Sendable {
    let name: String
    let price: Double
    let inStock: Bool
}

let product = try await agent.send(
    messages: [.user("Give me a JSON product example.")],
    as: Product.self
)
print(product.name, product.price)
```

Markdown code fences (` ```json ... ``` `) are stripped automatically before decoding.

---

## Prompt Caching (Anthropic)

Mark system messages or long context as cached to reduce latency and cost on repeated requests. Requires Claude 3.5+ / 3.7+ / 4.x.

```swift
let agent = try AIAgentImplementation.claudeSonnet46(apiKey: "sk-ant-...")

// The cached: true flag adds cache_control: {type:"ephemeral"} on this block
// and enables the anthropic-beta: prompt-caching-2024-07-31 header automatically
let messages: [AIMessage] = [
    .system("You are an expert in the following 100k-token document: \(document)", cached: true),
    .user("Summarize section 3.")
]

let response = try await agent.send(messages: messages)
```

---

## Function Calling (Tool Use)

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

// 3. Execute the tool and return results
if result.requiresToolExecution {
    for toolCall in result.toolCalls {
        let args = toolCall.decodeArguments() // [String: Any]?
        let toolResult = AIToolResult(toolCallId: toolCall.id, content: "22°C, sunny")
        let finalResponse = try await agent.send(
            messages: conversation + [result.asHistoryMessage],
            toolResults: [toolResult]
        )
        print(finalResponse.message.content)
    }
}
```

> **Tip:** For multi-step tool use, prefer `run(messages:tools:executor:maxSteps:)` over manual loops.

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

The persistence layer is powered by **SwiftData** and stores all data on-device. Requires iOS 17.0+ / macOS 14.0+.

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

// Load previous context
let previousMessages = try await agent.loadPreviousContext(limit: 20)
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

    // Agentic loop
    func run(messages: [AIMessage], tools: [AITool],
             executor: @Sendable (AIToolCall) async throws -> String,
             maxSteps: Int) async throws -> AIMessage

    // Structured outputs
    func send<T: Decodable & Sendable>(messages: [AIMessage], as type: T.Type) async throws -> T
}
```

### Convenience Initializers

```swift
// OpenAI
AIAgentImplementation.gpt4(apiKey:)
AIAgentImplementation.gpt4Turbo(apiKey:)
AIAgentImplementation.gpt4o(apiKey:)
AIAgentImplementation.gpt4oMini(apiKey:)
AIAgentImplementation.gpt41(apiKey:)
AIAgentImplementation.gpt41Mini(apiKey:)

// Anthropic — Claude 3
AIAgentImplementation.claude3Haiku(apiKey:)
AIAgentImplementation.claude3Sonnet(apiKey:)
AIAgentImplementation.claude3Opus(apiKey:)

// Anthropic — Claude 3.5 / 3.7
AIAgentImplementation.claude35Haiku(apiKey:)
AIAgentImplementation.claude35Sonnet(apiKey:)
AIAgentImplementation.claude37Sonnet(apiKey:)

// Anthropic — Claude 4
AIAgentImplementation.claudeHaiku45(apiKey:)
AIAgentImplementation.claudeSonnet46(apiKey:)
AIAgentImplementation.claudeOpus46(apiKey:)

// Google Gemini
AIAgentImplementation.gemini20Flash(apiKey:)
AIAgentImplementation.gemini20FlashLite(apiKey:)
AIAgentImplementation.gemini15Pro(apiKey:)
AIAgentImplementation.gemini15Flash(apiKey:)

// Ollama (local)
AIAgentImplementation.ollamaLlama32()
AIAgentImplementation.ollamaMistral()
AIAgentImplementation.ollamaCustom(name:maxTokens:)
```

### Retry Policies

```swift
RetryPolicy.default      // 3 retries, exponential backoff (1s → 60s)
RetryPolicy.none         // No retries
RetryPolicy.aggressive   // 5 retries, shorter delays (0.5s → 30s)

// Custom
RetryPolicy(maxRetries: 3, initialDelay: 1.0, maxDelay: 60.0, multiplier: 2.0)
```

### Error Handling

```swift
do {
    let response = try await agent.send(message: "Hello")
} catch let error as AIError {
    switch error {
    case .invalidAPIKey:            break
    case .rateLimit(let retryAfter): break
    case .tokenLimitExceeded(let current, let max): break
    case .networkError(let underlying): break
    case .timeout:                  break
    case .invalidResponse(let statusCode, let message): break
    case .streamingError(let reason): break
    case .agentLoopExceeded(let steps): break  // maxSteps reached in run()
    case .cancelled:                break
    case .decodingError, .invalidContext, .unknown: break
    }

    if error.isRecoverable {
        // rateLimit, networkError, and timeout are retried automatically
    }
}
```

---

## Architecture

```
Sources/SwiftAIAgentCore/
├── Core/
│   ├── AIAgentProtocol.swift       — AIAgent protocol + agentic loop + structured outputs
│   ├── AIMessage.swift             — Message model (user / assistant / system / tool)
│   ├── AIImageContent.swift        — Image attachment (.url / .data) for vision
│   ├── AIRole.swift                — Role enumeration
│   ├── AIModel.swift               — Model configs (OpenAI, Anthropic, Gemini, Ollama)
│   ├── AIConfiguration.swift       — Agent configuration and retry policies
│   ├── AIError.swift               — Typed error enum
│   ├── AITool.swift                — Tool (function) definition for tool use
│   └── AIToolCall.swift            — Tool call / result / response types
│
├── Network/
│   ├── NetworkClient.swift         — Base HTTP client with retry and SSE streaming
│   ├── OpenAIClient.swift          — OpenAI Chat Completions (also used for Ollama)
│   ├── AnthropicClient.swift       — Anthropic Messages API with prompt caching
│   ├── GeminiClient.swift          — Google Gemini generateContent / streamGenerateContent
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

`AIAgent` is a protocol — implement it to create test doubles:

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
        AIMessageWithTools(message: .assistant("Mocked result"))
    }

    func sendForJSON(messages: [AIMessage]) async throws -> AIMessage {
        .assistant("{\"key\": \"value\"}")
    }
}
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
