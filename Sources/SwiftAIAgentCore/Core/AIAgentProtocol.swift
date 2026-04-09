import Foundation

/// Protocol defining the core AI agent interface
public protocol AIAgent: Sendable {
    var configuration: AIConfiguration { get }

    func send(message: String) async throws -> String
    func send(messages: [AIMessage]) async throws -> AIMessage
    func stream(message: String) -> AsyncThrowingStream<String, Error>
    func stream(messages: [AIMessage]) -> AsyncThrowingStream<String, Error>
    func estimateTokens(for messages: [AIMessage]) -> Int

    /// Send messages with available tools — the model may decide to call one or more tools
    func send(messages: [AIMessage], tools: [AITool]) async throws -> AIMessageWithTools

    /// Send tool results back into an ongoing conversation
    func send(messages: [AIMessage], toolResults: [AIToolResult]) async throws -> AIMessageWithTools

    /// Internal hook used by send<T>() — override to enable native JSON mode (e.g. OpenAI json_object)
    func sendForJSON(messages: [AIMessage]) async throws -> AIMessage
}

// MARK: - Default implementations

public extension AIAgent {

    func send(message: String) async throws -> String {
        let response = try await send(messages: [.user(message)])
        return response.content
    }

    func stream(message: String) -> AsyncThrowingStream<String, Error> {
        stream(messages: [.user(message)])
    }

    func estimateTokens(for messages: [AIMessage]) -> Int {
        messages.reduce(0) { $0 + $1.estimatedTokens }
    }

    func send(messages: [AIMessage], tools: [AITool]) async throws -> AIMessageWithTools {
        let response = try await send(messages: messages)
        return AIMessageWithTools(message: response)
    }

    func send(messages: [AIMessage], toolResults: [AIToolResult]) async throws -> AIMessageWithTools {
        let resultMessages = toolResults.map { result in
            AIMessage.user("[Tool Result \(result.toolCallId)]: \(result.content)")
        }
        let response = try await send(messages: messages + resultMessages)
        return AIMessageWithTools(message: response)
    }

    func sendForJSON(messages: [AIMessage]) async throws -> AIMessage {
        try await send(messages: messages)
    }

    // MARK: - Feature 1: Agentic ReAct Loop

    /// Execute an agentic loop — automatically calls tools until the model produces a final text response.
    ///
    /// - Parameters:
    ///   - messages: Initial conversation history
    ///   - tools: Tools the model may invoke
    ///   - executor: Closure that executes a tool call and returns its string result
    ///   - maxSteps: Maximum tool-call rounds before throwing `agentLoopExceeded` (default: 10)
    func run(
        messages: [AIMessage],
        tools: [AITool],
        executor: @Sendable (AIToolCall) async throws -> String,
        maxSteps: Int
    ) async throws -> AIMessage {
        var history = messages

        for _ in 0..<maxSteps {
            let result = try await send(messages: history, tools: tools)

            // No tool calls — the model has produced its final answer
            guard result.requiresToolExecution else {
                return result.message
            }

            // Append the assistant message with embedded tool calls for correct history encoding
            history.append(result.asHistoryMessage)

            // Only execute tool calls whose names match the declared tools
            let validToolNames = Set(tools.map(\.name))
            for call in result.toolCalls {
                guard validToolNames.contains(call.name) else {
                    throw AIError.invalidContext("Model requested unknown tool: \(call.name)")
                }
                let output = try await executor(call)
                history.append(AIMessage(
                    role: .tool,
                    content: output,
                    metadata: ["tool_call_id": call.id]
                ))
            }
        }

        throw AIError.agentLoopExceeded(steps: maxSteps)
    }

    // MARK: - Feature 4: Structured Outputs

    /// Send messages and decode the JSON response directly into a Codable type.
    ///
    /// Uses native JSON mode when available (OpenAI, Gemini), otherwise injects
    /// a system instruction to force JSON output.
    func send<T: Decodable & Sendable>(messages: [AIMessage], as type: T.Type) async throws -> T {
        // Inject a JSON instruction when no system message exists
        var augmented = messages
        if !augmented.contains(where: { $0.role == .system }) {
            augmented.insert(
                .system("You must respond with valid JSON only. No markdown code blocks, no explanations."),
                at: 0
            )
        }

        let response = try await sendForJSON(messages: augmented)

        // Strip optional markdown code fences (```json ... ```)
        let raw = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned: String
        if raw.hasPrefix("```") {
            cleaned = raw
                .components(separatedBy: "\n")
                .dropFirst()
                .dropLast()
                .joined(separator: "\n")
        } else {
            cleaned = raw
        }

        guard let data = cleaned.data(using: .utf8) else {
            throw AIError.decodingError(
                DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Response is not valid UTF-8"))
            )
        }

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw AIError.decodingError(error)
        }
    }
}
