# 🤖 Swift AI Agent Core

> **Production-grade Swift package for integrating LLM agents into iOS apps with enterprise reliability**

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20watchOS%20%7C%20tvOS-blue.svg)](https://developer.apple.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![SPM Compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)

**Swift AI Agent Core** is a professional Swift package designed to seamlessly integrate AI language models (OpenAI GPT, Anthropic Claude) into your iOS, macOS, watchOS, and tvOS applications. Built with Swift 6.0 concurrency features, clean architecture principles, and production-grade reliability.

---

## ✨ Features

### 🚀 Core Capabilities
- **🌊 Streaming Support**: Real-time AI responses using `AsyncThrowingStream` for superior UX
- **🔄 Automatic Retry**: Built-in exponential backoff for transient failures
- **🎯 Smart Token Management**: Estimate and validate token usage before sending requests
- **🛡️ Comprehensive Error Handling**: Typed errors covering all failure scenarios
- **⚡ Swift 6.0 Concurrency**: Fully `Sendable` types with strict concurrency checking
- **🏗️ Clean Architecture**: Clear separation between Network, Domain, and Interface layers

### 🤝 Supported Providers
- **OpenAI**: GPT-4, GPT-4 Turbo, GPT-3.5 Turbo
- **Anthropic**: Claude 3 Opus, Sonnet, and Haiku

### 🎨 Developer Experience
- **Type-Safe**: Leverage Swift's type system for compile-time safety
- **Async/Await**: Modern concurrency with no callbacks or completion handlers
- **Protocol-Oriented**: Easy to mock and test
- **Zero Dependencies**: Pure Swift with no external dependencies

---

## 📦 Installation

### Swift Package Manager

Add SwiftAIAgentCore to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/VDurocher/Swift-AI-Agent-Core.git", from: "1.0.0")
]
```

Or add it via Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/VDurocher/Swift-AI-Agent-Core`
3. Select version and add to your target

---

## 🚀 Quick Start

### Basic Usage

```swift
import SwiftAIAgentCore

// 1. Create an agent with your API key
let agent = try AIAgentImplementation.gpt4(apiKey: "your-openai-api-key")

// 2. Send a message
let response = try await agent.send(message: "Explain Swift concurrency in one sentence.")
print(response)
// Output: "Swift concurrency uses async/await to write asynchronous code..."
```

### Streaming Responses

```swift
// Stream responses for better UX
print("Response: ", terminator: "")
for try await chunk in agent.stream(message: "Write a haiku about coding") {
    print(chunk, terminator: "")
}
// Output streams in real-time: "Code flows like water..."
```

### Multi-Turn Conversations

```swift
// Build context with conversation history
let conversation = [
    AIMessage.system("You are a Swift expert."),
    AIMessage.user("What is a protocol?"),
]

let response = try await agent.send(messages: conversation)
print(response.content)
```

### SwiftUI Integration

```swift
import SwiftUI
import SwiftAIAgentCore

struct ChatView: View {
    @State private var messages: [AIMessage] = []
    @State private var input = ""

    let agent: AIAgent

    var body: some View {
        VStack {
            ScrollView {
                ForEach(messages) { message in
                    HStack {
                        if message.role == .user {
                            Spacer()
                        }
                        Text(message.content)
                            .padding()
                            .background(message.role == .user ? Color.blue : Color.gray)
                            .cornerRadius(10)
                        if message.role == .assistant {
                            Spacer()
                        }
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
            print("Error: \(error)")
        }
    }
}
```

---

## 💾 Local Persistence

SwiftAIAgentCore includes a built-in conversation history layer powered by **SwiftData** (iOS 17+ / macOS 14+). All data is stored **locally on-device** — no server, no third party, privacy-first.

### Setup

```swift
import SwiftUI
import SwiftData
import SwiftAIAgentCore

// 1. Create the ModelContainer (once, at app startup)
let schema = Schema([ConversationRecord.self, MessageRecord.self])
let container = try ModelContainer(for: schema)

// 2. Create the HistoryManager (actors share the same container)
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

Display the conversation history with a built-in view that handles listing, navigation, and deletion:

```swift
@main
struct MyApp: App {
    let container = try! ModelContainer(for: ConversationRecord.self, MessageRecord.self)

    var body: some Scene {
        WindowGroup {
            HistoryView()
                .modelContainer(container)   // Required for @Query to work
        }
    }
}
```

### Resume Previous Context

Continue a conversation from a previous session:

```swift
// Load the last 20 messages from the most recent conversation
let previousMessages = try await agent.loadPreviousContext(limit: 20)

// Append new user input and send
let messages = previousMessages + [.user("Continue from where we left off")]
let response = try await agent.send(messages: messages)
```

### Availability

The persistence layer is gated on `@available(iOS 17.0, macOS 14.0, *)` because it relies on SwiftData. All existing iOS 16+ functionality remains unchanged.

---

## 🏗️ Architecture

```
SwiftAIAgentCore/
├── Core/                    # Domain Layer
│   ├── AIAgentProtocol      # Main protocol defining agent interface
│   ├── AIMessage            # Message model (user, assistant, system)
│   ├── AIRole               # Role enumeration
│   ├── AIModel              # Model configurations (GPT-4, Claude, etc.)
│   ├── AIConfiguration      # Agent configuration with retry policies
│   └── AIError              # Comprehensive error types
│
├── Network/                 # Network Layer
│   ├── NetworkClient        # Base client with retry logic
│   ├── OpenAIClient         # OpenAI API implementation
│   ├── AnthropicClient      # Anthropic API implementation
│   └── AIAgentImplementation # Concrete AIAgent implementation
│
├── Persistence/             # Local Storage Layer (iOS 17+ / macOS 14+)
│   ├── ConversationRecord   # SwiftData model for conversations
│   ├── MessageRecord        # SwiftData model for messages
│   └── HistoryManager       # @ModelActor — thread-safe history operations
│
├── UI/                      # SwiftUI Components (iOS 17+ / macOS 14+)
│   ├── HistoryView          # Conversation list with delete support
│   └── ConversationDetailView # Message-level conversation view
│
└── Utils/                   # Utilities
    └── TokenEstimator       # Token counting and validation
```

### Key Design Principles

1. **Separation of Concerns**: Network, Domain, and Interface layers are clearly separated
2. **Protocol-Oriented**: Easy to mock and extend with custom implementations
3. **Concurrency-Safe**: All types are `Sendable` and use actors where needed
4. **Error Recovery**: Automatic retry with exponential backoff for transient failures
5. **Resource Management**: Token estimation prevents expensive failed requests

---

## 📚 API Documentation

### AIAgent Protocol

The core protocol defining AI agent capabilities:

```swift
public protocol AIAgent: Sendable {
    var configuration: AIConfiguration { get }

    func send(message: String) async throws -> String
    func send(messages: [AIMessage]) async throws -> AIMessage
    func stream(message: String) -> AsyncThrowingStream<String, Error>
    func stream(messages: [AIMessage]) -> AsyncThrowingStream<String, Error>
    func estimateTokens(for messages: [AIMessage]) -> Int
}
```

### AIConfiguration

Configure your agent with custom settings:

```swift
let config = AIConfiguration(
    model: .gpt4Turbo,           // AI model to use
    apiKey: "your-api-key",       // Your API key
    temperature: 0.7,             // 0.0-2.0 (higher = more creative)
    maxResponseTokens: 2000,      // Max tokens in response
    timeout: 30,                  // Request timeout in seconds
    retryPolicy: .default         // Retry strategy
)

let agent = try AIAgentImplementation(configuration: config)
```

### Retry Policies

Built-in retry strategies:

```swift
// Default: 3 retries with exponential backoff
RetryPolicy.default

// No retries
RetryPolicy.none

// Aggressive: 5 retries with shorter delays
RetryPolicy.aggressive

// Custom
RetryPolicy(
    maxRetries: 3,
    initialDelay: 1.0,
    maxDelay: 60.0,
    multiplier: 2.0
)
```

### Token Management

Estimate and validate token usage:

```swift
let messages = [
    AIMessage.system("You are helpful."),
    AIMessage.user("Hello!")
]

// Estimate token count
let tokens = TokenEstimator.estimate(messages: messages)
print("Estimated tokens: \(tokens)")

// Validate against model limits
try TokenEstimator.validate(
    messages: messages,
    model: .gpt4,
    maxResponseTokens: 1000
)

// Truncate if needed
let truncated = TokenEstimator.truncate(
    messages: messages,
    limit: 2000,
    keepSystemMessages: true
)
```

### Error Handling

Comprehensive error types:

```swift
do {
    let response = try await agent.send(message: "Hello")
} catch let error as AIError {
    switch error {
    case .invalidAPIKey:
        print("Invalid API key")

    case .rateLimit(let retryAfter):
        print("Rate limited. Retry after \(retryAfter ?? 0)s")

    case .tokenLimitExceeded(let current, let max):
        print("Token limit exceeded: \(current)/\(max)")

    case .networkError(let underlying):
        print("Network error: \(underlying)")

    case .timeout:
        print("Request timed out")

    default:
        print("Error: \(error.localizedDescription)")
    }

    // Check if recoverable
    if error.isRecoverable {
        // Retry logic handled automatically
    }
}
```

---

## 🎯 Advanced Usage

### Multiple AI Providers

Use different models for different tasks:

```swift
// GPT-4 for complex reasoning
let gptAgent = try AIAgentImplementation.gpt4(apiKey: openAIKey)

// Claude for longer context
let claudeAgent = try AIAgentImplementation.claude3Opus(apiKey: anthropicKey)

// Query both simultaneously
async let gptResponse = gptAgent.send(message: prompt)
async let claudeResponse = claudeAgent.send(message: prompt)

let responses = try await [gptResponse, claudeResponse]
```

### Conversation Management

Handle long conversations with token limits:

```swift
var conversation: [AIMessage] = [.system("You are helpful.")]

func chat(_ message: String) async throws -> String {
    conversation.append(.user(message))

    // Check token count
    let tokens = TokenEstimator.estimate(messages: conversation)

    // Truncate if approaching limit
    if tokens > 3000 {
        conversation = TokenEstimator.truncate(
            messages: conversation,
            limit: 2000,
            keepSystemMessages: true
        )
    }

    let response = try await agent.send(messages: conversation)
    conversation.append(response)
    return response.content
}
```

### Custom Models

Add support for new models:

```swift
let customModel = AIModel(
    provider: .openai,
    name: "gpt-5-preview",
    maxTokens: 200000,
    supportsStreaming: true
)

let config = AIConfiguration(model: customModel, apiKey: apiKey)
let agent = try AIAgentImplementation(configuration: config)
```

---

## 🧪 Testing

The package includes comprehensive unit tests:

```bash
swift test
```

### Mocking for Tests

```swift
class MockAIAgent: AIAgent {
    var configuration: AIConfiguration

    func send(messages: [AIMessage]) async throws -> AIMessage {
        return .assistant("Mocked response")
    }

    func stream(messages: [AIMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield("Mocked ")
            continuation.yield("stream")
            continuation.finish()
        }
    }
}
```

---

## 📖 Examples

Check out the [Examples](Examples/) directory for:
- **BasicExample.swift**: Simple usage patterns
- **AdvancedExample.swift**: Production-grade implementations
- **SwiftUI integration**: Complete chat interface

Run examples:
```bash
cd Examples
export OPENAI_API_KEY="your-key"
swift run BasicExample
```

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Development Setup

```bash
git clone https://github.com/VDurocher/Swift-AI-Agent-Core.git
cd Swift-AI-Agent-Core
swift build
swift test
```

---

## 📋 Requirements

- iOS 16.0+ / macOS 13.0+ / watchOS 9.0+ / tvOS 16.0+
- Swift 6.0+
- Xcode 16.0+

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- Built with ❤️ using Swift 6.0
- Inspired by best practices from the iOS development community
- Special thanks to OpenAI and Anthropic for their amazing APIs

---

## 📬 Contact

**Vincent Durocher**
- GitHub: [@VDurocher](https://github.com/VDurocher)

---

## ⭐ Star History

If you find this package useful, please consider giving it a star! It helps others discover the project.

---

<p align="center">Made with ❤️ for the iOS developer community</p>
