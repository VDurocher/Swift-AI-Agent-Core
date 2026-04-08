import Foundation

/// Anthropic (Claude) API client implementation
actor AnthropicClient: Sendable {
    private let networkClient: NetworkClient
    private let configuration: AIConfiguration

    init(configuration: AIConfiguration) {
        self.configuration = configuration
        self.networkClient = NetworkClient(retryPolicy: configuration.retryPolicy)
    }

    // MARK: - Public Methods

    func sendCompletion(messages: [AIMessage]) async throws -> AIMessage {
        let request = try createRequest(messages: messages, tools: nil, stream: false)
        let (data, _) = try await networkClient.execute(request: request)

        let response = try JSONDecoder().decode(AnthropicMessagesResponse.self, from: data)

        guard let textContent = response.content.first(where: { $0.type == "text" })?.text else {
            throw AIError.invalidResponse(statusCode: 200, message: "No content in response")
        }

        return AIMessage(role: .assistant, content: textContent)
    }

    /// Sends messages with available tools — the model may return tool calls
    func sendCompletionWithTools(messages: [AIMessage], tools: [AITool]) async throws -> AIMessageWithTools {
        let request = try createRequest(messages: messages, tools: tools, stream: false)
        let (data, _) = try await networkClient.execute(request: request)

        let response = try JSONDecoder().decode(AnthropicMessagesResponse.self, from: data)

        let textContent = response.content.first(where: { $0.type == "text" })?.text ?? ""

        let toolCalls: [AIToolCall] = response.content.compactMap { block in
            guard block.type == "tool_use",
                  let callId = block.id,
                  let toolName = block.name else { return nil }
            let arguments = block.input?.toJSONString() ?? "{}"
            return AIToolCall(id: callId, name: toolName, arguments: arguments)
        }

        let assistantMessage = AIMessage(role: .assistant, content: textContent)
        return AIMessageWithTools(message: assistantMessage, toolCalls: toolCalls)
    }

    func streamCompletion(messages: [AIMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = try createRequest(messages: messages, tools: nil, stream: true)
                    let stream = await networkClient.stream(request: request)

                    for try await data in stream {
                        let lines = String(data: data, encoding: .utf8)?
                            .components(separatedBy: "\n")
                            .filter { !$0.isEmpty } ?? []

                        for line in lines {
                            guard line.hasPrefix("data: ") else { continue }
                            let jsonString = String(line.dropFirst(6))

                            if let eventData = jsonString.data(using: .utf8),
                               let event = try? JSONDecoder().decode(AnthropicStreamEvent.self, from: eventData) {
                                switch event.type {
                                case "content_block_delta":
                                    if let text = event.delta?.text {
                                        continuation.yield(text)
                                    }
                                case "message_stop":
                                    continuation.finish()
                                    return
                                default:
                                    break
                                }
                            }
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func createRequest(messages: [AIMessage], tools: [AITool]?, stream: Bool) throws -> URLRequest {
        try configuration.validate()

        let rawURL = "\(configuration.model.provider.baseURL)/messages"
        guard let url = URL(string: rawURL) else {
            throw AIError.invalidContext("Invalid Anthropic endpoint URL: \(rawURL)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = configuration.timeout

        let systemMessage = messages.first(where: { $0.role == .system })?.content
        let conversationMessages = messages.filter { $0.role != .system }

        let anthropicMessages = conversationMessages.map { message -> AnthropicMessage in
            if message.role == .tool, let toolCallId = message.metadata?["tool_call_id"] {
                let block = AnthropicToolResultBlock(toolUseId: toolCallId, content: message.content)
                return AnthropicMessage(role: "user", content: .toolResults([block]))
            }
            return AnthropicMessage(role: message.role.anthropicName, content: .text(message.content))
        }

        let toolDefinitions = tools.map { toolArray in
            toolArray.map { tool in
                AnthropicToolDefinition(
                    name: tool.name,
                    description: tool.description,
                    inputSchema: tool.parameters
                )
            }
        }

        let requestBody = AnthropicMessagesRequest(
            model: configuration.model.name,
            messages: anthropicMessages,
            maxTokens: configuration.maxResponseTokens,
            temperature: configuration.temperature,
            system: systemMessage,
            stream: stream,
            tools: toolDefinitions
        )

        request.httpBody = try JSONEncoder().encode(requestBody)
        return request
    }
}
