import Foundation

/// OpenAI API client implementation
actor OpenAIClient: Sendable {
    private let networkClient: NetworkClient
    private let configuration: AIConfiguration

    init(configuration: AIConfiguration) {
        self.configuration = configuration
        self.networkClient = NetworkClient(retryPolicy: configuration.retryPolicy)
    }

    // MARK: - Request/Response Models

    private struct ChatCompletionRequest: Encodable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let maxTokens: Int
        let stream: Bool
        /// Available tools for function calling (optional)
        let tools: [ToolDefinition]?

        enum CodingKeys: String, CodingKey {
            case model, messages, temperature, tools
            case maxTokens = "max_tokens"
            case stream
        }

        struct Message: Encodable {
            let role: String
            let content: String
            /// Identifier of the tool call this message responds to (role "tool" only)
            let toolCallId: String?

            enum CodingKeys: String, CodingKey {
                case role, content
                case toolCallId = "tool_call_id"
            }

            init(role: String, content: String, toolCallId: String? = nil) {
                self.role = role
                self.content = content
                self.toolCallId = toolCallId
            }
        }

        /// Tool definition in OpenAI function calling format
        struct ToolDefinition: Encodable {
            /// Always "function" for the OpenAI format
            let type: String
            let function: FunctionDefinition

            struct FunctionDefinition: Encodable {
                let name: String
                let description: String
                let parameters: AITool.AIToolParameters
            }
        }
    }

    private struct ChatCompletionResponse: Decodable {
        let id: String
        let choices: [Choice]

        struct Choice: Decodable {
            let message: Message
            let finishReason: String?

            enum CodingKeys: String, CodingKey {
                case message
                case finishReason = "finish_reason"
            }
        }

        struct Message: Decodable {
            let role: String
            /// Text content — may be nil if the model only calls tools
            let content: String?
            /// Tool calls requested by the model (nil for text responses)
            let toolCalls: [ToolCallResponse]?

            enum CodingKeys: String, CodingKey {
                case role, content
                case toolCalls = "tool_calls"
            }
        }

        /// Tool call as returned by the OpenAI API
        struct ToolCallResponse: Decodable {
            let id: String
            let function: FunctionCall

            struct FunctionCall: Decodable {
                let name: String
                let arguments: String
            }
        }
    }

    private struct StreamChunk: Decodable {
        let choices: [Choice]

        struct Choice: Decodable {
            let delta: Delta
            let finishReason: String?

            enum CodingKeys: String, CodingKey {
                case delta
                case finishReason = "finish_reason"
            }
        }

        struct Delta: Decodable {
            let content: String?
        }
    }

    // MARK: - Public Methods

    func sendCompletion(messages: [AIMessage]) async throws -> AIMessage {
        let request = try createRequest(messages: messages, tools: nil, stream: false)
        let (data, _) = try await networkClient.execute(request: request)

        let response = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)

        guard let choice = response.choices.first else {
            throw AIError.invalidResponse(statusCode: 200, message: "No choices in response")
        }

        return AIMessage(
            role: AIRole(rawValue: choice.message.role) ?? .assistant,
            content: choice.message.content ?? ""
        )
    }

    /// Sends messages with available tools — the model may return tool calls
    func sendCompletionWithTools(messages: [AIMessage], tools: [AITool]) async throws -> AIMessageWithTools {
        let request = try createRequest(messages: messages, tools: tools, stream: false)
        let (data, _) = try await networkClient.execute(request: request)

        let response = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)

        guard let choice = response.choices.first else {
            throw AIError.invalidResponse(statusCode: 200, message: "No choices in response")
        }

        // Convert OpenAI tool call responses to AIToolCall
        let toolCalls: [AIToolCall] = choice.message.toolCalls?.map { callResponse in
            AIToolCall(
                id: callResponse.id,
                name: callResponse.function.name,
                arguments: callResponse.function.arguments
            )
        } ?? []

        let assistantMessage = AIMessage(
            role: .assistant,
            content: choice.message.content ?? ""
        )

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

                            if jsonString == "[DONE]" {
                                continuation.finish()
                                return
                            }

                            if let data = jsonString.data(using: .utf8),
                               let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data),
                               let content = chunk.choices.first?.delta.content {
                                continuation.yield(content)
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

        // Fail explicitly if the base URL is invalid — never crash in production
        let rawURL = "\(configuration.model.provider.baseURL)/chat/completions"
        guard let url = URL(string: rawURL) else {
            throw AIError.invalidContext("Invalid OpenAI endpoint URL: \(rawURL)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = configuration.timeout

        // Convert messages to OpenAI format, handling the "tool" role for results
        let openAIMessages = messages.map { message -> ChatCompletionRequest.Message in
            let toolCallId = message.role == .tool ? message.metadata?["tool_call_id"] : nil
            return ChatCompletionRequest.Message(
                role: message.role.openAIName,
                content: message.content,
                toolCallId: toolCallId
            )
        }

        // Convert AITool values to OpenAI ToolDefinition if provided
        let toolDefinitions = tools.map { toolArray in
            toolArray.map { tool in
                ChatCompletionRequest.ToolDefinition(
                    type: "function",
                    function: .init(
                        name: tool.name,
                        description: tool.description,
                        parameters: tool.parameters
                    )
                )
            }
        }

        let requestBody = ChatCompletionRequest(
            model: configuration.model.name,
            messages: openAIMessages,
            temperature: configuration.temperature,
            maxTokens: configuration.maxResponseTokens,
            stream: stream,
            tools: toolDefinitions
        )

        request.httpBody = try JSONEncoder().encode(requestBody)
        return request
    }
}
