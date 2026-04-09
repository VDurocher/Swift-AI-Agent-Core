import Foundation

/// OpenAI API client — also used for Ollama (OpenAI-compatible endpoint)
actor OpenAIClient: Sendable {
    private let networkClient: NetworkClient
    private let configuration: AIConfiguration

    init(configuration: AIConfiguration) {
        self.configuration = configuration
        self.networkClient = NetworkClient(retryPolicy: configuration.retryPolicy)
    }

    // MARK: - Public Methods

    func sendCompletion(messages: [AIMessage]) async throws -> AIMessage {
        try await sendInternal(messages: messages, tools: nil, stream: false, jsonMode: false)
    }

    func sendCompletionJSON(messages: [AIMessage]) async throws -> AIMessage {
        try await sendInternal(messages: messages, tools: nil, stream: false, jsonMode: true)
    }

    func sendCompletionWithTools(messages: [AIMessage], tools: [AITool]) async throws -> AIMessageWithTools {
        let request = try buildRequest(messages: messages, tools: tools, stream: false, jsonMode: false)
        let (data, _) = try await networkClient.execute(request: request)
        let response = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)

        guard let choice = response.choices.first else {
            throw AIError.invalidResponse(statusCode: 200, message: "No choices in response")
        }

        let toolCalls: [AIToolCall] = choice.message.toolCalls?.map { call in
            AIToolCall(id: call.id, name: call.function.name, arguments: call.function.arguments)
        } ?? []

        return AIMessageWithTools(
            message: AIMessage(role: .assistant, content: choice.message.content ?? ""),
            toolCalls: toolCalls
        )
    }

    func streamCompletion(messages: [AIMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try self.buildRequest(messages: messages, tools: nil, stream: true, jsonMode: false)
                    let stream = await self.networkClient.stream(request: request)

                    for try await data in stream {
                        let lines = String(data: data, encoding: .utf8)?
                            .components(separatedBy: "\n")
                            .filter { !$0.isEmpty } ?? []

                        for line in lines {
                            guard line.hasPrefix("data: ") else { continue }
                            let json = String(line.dropFirst(6))
                            if json == "[DONE]" { continuation.finish(); return }

                            if let chunkData = json.data(using: .utf8),
                               let chunk = try? JSONDecoder().decode(StreamChunk.self, from: chunkData),
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
            // Cancel the network task when the consumer stops iterating the stream
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Private Helpers

    private func sendInternal(messages: [AIMessage], tools: [AITool]?, stream: Bool, jsonMode: Bool) async throws -> AIMessage {
        let request = try buildRequest(messages: messages, tools: tools, stream: stream, jsonMode: jsonMode)
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

    private func buildRequest(messages: [AIMessage], tools: [AITool]?, stream: Bool, jsonMode: Bool) throws -> URLRequest {
        try configuration.validate()

        let rawURL = "\(configuration.model.provider.baseURL)/chat/completions"
        guard let url = URL(string: rawURL) else {
            throw AIError.invalidContext("Invalid endpoint URL: \(rawURL)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = configuration.timeout

        let encodedMessages = messages.map { encodeMessage($0) }
        let toolDefs = tools.map { $0.map { ToolDefinition(from: $0) } }
        let format = jsonMode ? ResponseFormat(type: "json_object") : nil

        let body = ChatCompletionRequest(
            model: configuration.model.name,
            messages: encodedMessages,
            temperature: configuration.temperature,
            maxTokens: configuration.maxResponseTokens,
            stream: stream,
            tools: toolDefs,
            responseFormat: format
        )

        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    /// Converts an AIMessage into the OpenAI wire format, handling vision and tool_calls
    private func encodeMessage(_ message: AIMessage) -> OutboundMessage {
        // Assistant messages with tool calls need the tool_calls field
        if message.role == .assistant, let calls = message.toolCalls, !calls.isEmpty {
            let outCalls = calls.map { call in
                ToolCallOutbound(id: call.id, function: .init(name: call.name, arguments: call.arguments))
            }
            return OutboundMessage(role: message.role.openAIName, stringContent: message.content, toolCallId: nil, toolCalls: outCalls, parts: nil)
        }

        // Tool result messages need tool_call_id
        if message.role == .tool, let callId = message.metadata?["tool_call_id"] {
            return OutboundMessage(role: "tool", stringContent: message.content, toolCallId: callId, toolCalls: nil, parts: nil)
        }

        // Messages with images use the parts array format
        if let images = message.images, !images.isEmpty {
            var parts: [ContentPart] = [.text(message.content)]
            for image in images {
                switch image {
                case .url(let url):
                    parts.append(.imageURL(url.absoluteString))
                case .data(let bytes, let mime):
                    parts.append(.imageURL("data:\(mime);base64,\(bytes.base64EncodedString())"))
                }
            }
            return OutboundMessage(role: message.role.openAIName, stringContent: nil, toolCallId: nil, toolCalls: nil, parts: parts)
        }

        return OutboundMessage(role: message.role.openAIName, stringContent: message.content, toolCallId: nil, toolCalls: nil, parts: nil)
    }
}

// MARK: - Request / Response Models

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [OutboundMessage]
    let temperature: Double
    let maxTokens: Int
    let stream: Bool
    let tools: [ToolDefinition]?
    let responseFormat: ResponseFormat?

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, stream, tools
        case maxTokens = "max_tokens"
        case responseFormat = "response_format"
    }
}

private struct ResponseFormat: Encodable {
    let type: String
}

/// OpenAI message with polymorphic content (string or parts array)
private struct OutboundMessage: Encodable {
    let role: String
    let stringContent: String?
    let toolCallId: String?
    let toolCalls: [ToolCallOutbound]?
    let parts: [ContentPart]?

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(role, forKey: .role)
        if let calls = toolCalls, !calls.isEmpty {
            try c.encode(stringContent ?? "", forKey: .content)
            try c.encode(calls, forKey: .toolCalls)
        } else if let parts {
            try c.encode(parts, forKey: .content)
        } else {
            try c.encode(stringContent ?? "", forKey: .content)
        }
        if let id = toolCallId { try c.encode(id, forKey: .toolCallId) }
    }

    enum Keys: String, CodingKey {
        case role, content
        case toolCallId = "tool_call_id"
        case toolCalls = "tool_calls"
    }
}

private enum ContentPart: Encodable {
    case text(String)
    case imageURL(String)

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: PartKeys.self)
        switch self {
        case .text(let t):
            try c.encode("text", forKey: .type)
            try c.encode(t, forKey: .text)
        case .imageURL(let url):
            try c.encode("image_url", forKey: .type)
            try c.encode(["url": url], forKey: .imageURL)
        }
    }

    enum PartKeys: String, CodingKey {
        case type, text
        case imageURL = "image_url"
    }
}

private struct ToolCallOutbound: Encodable {
    let id: String
    let type = "function"
    let function: FunctionRef

    struct FunctionRef: Encodable {
        let name: String
        let arguments: String
    }
}

private struct ToolDefinition: Encodable {
    let type = "function"
    let function: FunctionDef

    struct FunctionDef: Encodable {
        let name: String
        let description: String
        let parameters: AITool.AIToolParameters
    }

    init(from tool: AITool) {
        self.function = FunctionDef(name: tool.name, description: tool.description, parameters: tool.parameters)
    }
}

private struct ChatCompletionResponse: Decodable {
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
        let content: String?
        let toolCalls: [ToolCallResponse]?

        enum CodingKeys: String, CodingKey {
            case role, content
            case toolCalls = "tool_calls"
        }
    }

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

        struct Delta: Decodable {
            let content: String?
        }
    }
}
