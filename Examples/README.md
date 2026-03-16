# SwiftAIAgentCore Examples

This directory contains example code demonstrating how to use SwiftAIAgentCore in your iOS/macOS applications.

## Running the Examples

### Prerequisites

1. **API Keys**: You'll need API keys from OpenAI and/or Anthropic:
   - OpenAI: https://platform.openai.com/api-keys
   - Anthropic: https://console.anthropic.com/

2. **Set Environment Variables**:
   ```bash
   export OPENAI_API_KEY="your-openai-key"
   export ANTHROPIC_API_KEY="your-anthropic-key"
   ```

### Basic Example

The `BasicExample.swift` demonstrates:
- Creating an AI agent
- Sending simple messages
- Streaming responses in real-time
- Multi-turn conversations

To run:
```bash
swift run BasicExample
```

### Advanced Example

The `AdvancedExample.swift` shows:
- Custom configuration with retry policies
- Token estimation and validation
- Comprehensive error handling
- Using multiple AI providers
- Conversation management with truncation

## Integration in Your App

### 1. Add the Package

Add SwiftAIAgentCore to your Xcode project via Swift Package Manager:

```
https://github.com/VDurocher/Swift-AI-Agent-Core
```

### 2. Import and Use

```swift
import SwiftAIAgentCore

// Create an agent
let agent = try AIAgentImplementation.gpt4(apiKey: apiKey)

// Send a message
let response = try await agent.send(message: "Hello!")

// Stream a response
for try await chunk in agent.stream(message: "Tell me a story") {
    print(chunk, terminator: "")
}
```

### 3. SwiftUI Example

```swift
import SwiftUI
import SwiftAIAgentCore

struct ChatView: View {
    @State private var messages: [AIMessage] = []
    @State private var input = ""
    @State private var isLoading = false

    let agent: AIAgent

    var body: some View {
        VStack {
            ScrollView {
                ForEach(messages) { message in
                    MessageRow(message: message)
                }
            }

            HStack {
                TextField("Message", text: $input)
                Button("Send") {
                    Task { await sendMessage() }
                }
                .disabled(isLoading)
            }
        }
    }

    func sendMessage() async {
        guard !input.isEmpty else { return }

        let userMessage = AIMessage.user(input)
        messages.append(userMessage)
        input = ""
        isLoading = true

        do {
            let response = try await agent.send(messages: messages)
            messages.append(response)
        } catch {
            print("Error: \(error)")
        }

        isLoading = false
    }
}
```

## Best Practices

1. **API Key Security**: Never hardcode API keys. Use environment variables or secure storage.

2. **Error Handling**: Always wrap AI calls in do-catch blocks and handle specific error types.

3. **Token Management**: Use `TokenEstimator` to validate message size before sending.

4. **Retry Logic**: Configure appropriate retry policies based on your use case.

5. **Streaming**: Use streaming for long responses to improve perceived performance.

6. **Conversation Context**: Truncate old messages when approaching token limits.

## Troubleshooting

### "Invalid API Key" Error
- Verify your API key is correct and active
- Check that you're using the right key for the right provider

### Rate Limit Errors
- Implement exponential backoff (already built into the library)
- Consider using aggressive retry policy
- Monitor your API usage

### Token Limit Errors
- Use `TokenEstimator.validate()` before sending
- Truncate conversations with `TokenEstimator.truncate()`
- Reduce `maxResponseTokens` in configuration

## Learn More

- [Main README](../README.md)
- [OpenAI API Documentation](https://platform.openai.com/docs)
- [Anthropic API Documentation](https://docs.anthropic.com)
