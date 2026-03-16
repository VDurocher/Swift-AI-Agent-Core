import Foundation
import SwiftAIAgentCore

/// Advanced example demonstrating production-grade features
///
/// This example shows:
/// - Custom configuration with retry policies
/// - Token estimation and validation
/// - Error handling and recovery
/// - Multiple AI providers (OpenAI and Anthropic)
/// - Conversation management

struct AdvancedExample {

    // MARK: - Custom Configuration

    static func customConfigurationExample() async throws {
        print("⚙️ Example: Custom Configuration\n")

        let config = AIConfiguration(
            model: .gpt4Turbo,
            apiKey: "your-api-key",
            temperature: 0.5,  // More deterministic
            maxResponseTokens: 500,
            timeout: 60,
            retryPolicy: .aggressive  // More aggressive retry
        )

        let agent = try AIAgentImplementation(configuration: config)

        print("✅ Agent configured with custom settings")
        print("   Model: \(config.model.name)")
        print("   Temperature: \(config.temperature)")
        print("   Max tokens: \(config.maxResponseTokens)\n")
    }

    // MARK: - Token Management

    static func tokenManagementExample() async throws {
        print("🎫 Example: Token Management\n")

        let messages = [
            AIMessage.system("You are a helpful assistant."),
            AIMessage.user("Explain quantum computing."),
        ]

        // Estimate tokens before sending
        let estimatedTokens = TokenEstimator.estimate(messages: messages)
        print("Estimated tokens: \(estimatedTokens)")

        // Check if it fits within limits
        let fitsInGPT35 = TokenEstimator.fitsWithin(messages: messages, limit: 4000)
        print("Fits in GPT-3.5 context: \(fitsInGPT35)")

        // Validate against model
        do {
            try TokenEstimator.validate(
                messages: messages,
                model: .gpt4,
                maxResponseTokens: 1000
            )
            print("✅ Messages validated successfully\n")
        } catch {
            print("❌ Token validation failed: \(error)\n")
        }
    }

    // MARK: - Error Handling

    static func errorHandlingExample() async throws {
        print("🛡️ Example: Error Handling\n")

        let agent = try AIAgentImplementation.gpt4(apiKey: "invalid-key")

        do {
            _ = try await agent.send(message: "Hello")
        } catch let error as AIError {
            switch error {
            case .invalidAPIKey:
                print("❌ API key is invalid")
            case .rateLimit(let retryAfter):
                if let retry = retryAfter {
                    print("⏳ Rate limited. Retry after \(retry) seconds")
                }
            case .networkError(let underlying):
                print("🌐 Network error: \(underlying)")
            case .tokenLimitExceeded(let current, let max):
                print("📊 Token limit exceeded: \(current)/\(max)")
            default:
                print("❌ Error: \(error.errorDescription ?? "Unknown")")
            }

            // Check if error is recoverable
            if error.isRecoverable {
                print("♻️ This error can be retried\n")
            } else {
                print("🚫 This error cannot be retried\n")
            }
        }
    }

    // MARK: - Multiple Providers

    static func multipleProvidersExample() async throws {
        print("🔄 Example: Multiple AI Providers\n")

        // OpenAI Agent
        let gptAgent = try AIAgentImplementation.gpt4(
            apiKey: ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        )

        // Anthropic Agent
        let claudeAgent = try AIAgentImplementation.claude3Sonnet(
            apiKey: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        )

        let prompt = "What is Swift in one sentence?"

        // Query both
        async let gptResponse = gptAgent.send(message: prompt)
        async let claudeResponse = claudeAgent.send(message: prompt)

        print("GPT-4: \(try await gptResponse)")
        print("Claude: \(try await claudeResponse)\n")
    }

    // MARK: - Conversation Management

    static func conversationManagementExample() async throws {
        print("💬 Example: Conversation Management\n")

        let agent = try AIAgentImplementation.gpt4(apiKey: "your-api-key")

        var conversation: [AIMessage] = [
            .system("You are a Swift expert. Keep responses concise.")
        ]

        // Helper to add messages and get responses
        func chat(_ userMessage: String) async throws -> String {
            conversation.append(.user(userMessage))

            // Check token count before sending
            let tokens = TokenEstimator.estimate(messages: conversation)
            print("Current tokens: \(tokens)")

            // Truncate if needed
            if tokens > 3000 {
                conversation = TokenEstimator.truncate(
                    messages: conversation,
                    limit: 2000,
                    keepSystemMessages: true
                )
                print("⚠️ Truncated conversation to fit limits")
            }

            let response = try await agent.send(messages: conversation)
            conversation.append(response)
            return response.content
        }

        // Simulated multi-turn conversation
        _ = try await chat("What is a protocol?")
        _ = try await chat("Give me an example.")
        _ = try await chat("How is it different from inheritance?")

        print("Final conversation has \(conversation.count) messages\n")
    }
}
