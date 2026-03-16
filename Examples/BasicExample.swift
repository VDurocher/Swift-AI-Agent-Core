import Foundation
import SwiftAIAgentCore

/// Basic example demonstrating how to use SwiftAIAgentCore
///
/// This example shows:
/// - Creating an AI agent
/// - Sending simple messages
/// - Handling conversations with multiple messages
/// - Streaming responses
/// - Error handling

@main
struct BasicExample {
    static func main() async {
        print("🤖 SwiftAIAgentCore - Basic Example\n")

        // IMPORTANT: Replace with your actual API key
        let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? "your-api-key-here"

        do {
            try await runBasicExample(apiKey: apiKey)
            try await runStreamingExample(apiKey: apiKey)
            try await runConversationExample(apiKey: apiKey)
        } catch {
            print("❌ Error: \(error.localizedDescription)")
        }
    }

    // MARK: - Basic Example

    static func runBasicExample(apiKey: String) async throws {
        print("📝 Example 1: Basic Message\n")

        // Create an agent with GPT-4
        let agent = try AIAgentImplementation.gpt4(apiKey: apiKey)

        // Send a simple message
        let response = try await agent.send(message: "What is Swift? Answer in one sentence.")

        print("Response: \(response)\n")
        print("---\n")
    }

    // MARK: - Streaming Example

    static func runStreamingExample(apiKey: String) async throws {
        print("🌊 Example 2: Streaming Response\n")

        let agent = try AIAgentImplementation.gpt4(apiKey: apiKey)

        print("Response: ", terminator: "")

        // Stream the response in real-time
        for try await chunk in agent.stream(message: "Count from 1 to 5 slowly.") {
            print(chunk, terminator: "")
            fflush(stdout)
        }

        print("\n\n---\n")
    }

    // MARK: - Conversation Example

    static func runConversationExample(apiKey: String) async throws {
        print("💬 Example 3: Multi-turn Conversation\n")

        let agent = try AIAgentImplementation.gpt4(apiKey: apiKey)

        // Build a conversation with context
        let conversation = [
            AIMessage.system("You are a helpful Swift programming assistant."),
            AIMessage.user("What is the difference between struct and class in Swift?"),
        ]

        let response = try await agent.send(messages: conversation)
        print("Assistant: \(response.content)\n")

        // Continue the conversation
        var updatedConversation = conversation
        updatedConversation.append(response)
        updatedConversation.append(.user("Give me a code example."))

        let finalResponse = try await agent.send(messages: updatedConversation)
        print("Assistant: \(finalResponse.content)\n")

        print("---\n")
    }
}
