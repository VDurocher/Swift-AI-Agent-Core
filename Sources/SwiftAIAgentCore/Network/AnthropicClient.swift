import Foundation

/// Anthropic (Claude) API client implementation
actor AnthropicClient: Sendable {
    private let networkClient: NetworkClient
    private let configuration: AIConfiguration

    init(configuration: AIConfiguration) {
        self.configuration = configuration
        self.networkClient = NetworkClient(retryPolicy: configuration.retryPolicy)
    }

    // MARK: - Request/Response Models

    private struct MessagesRequest: Encodable {
        let model: String
        let messages: [Message]
        let maxTokens: Int
        let temperature: Double
        let system: String?
        let stream: Bool
        /// Available tools in Anthropic format (optional)
        let tools: [ToolDefinition]?

        enum CodingKeys: String, CodingKey {
            case model, messages, temperature, system, stream, tools
            case maxTokens = "max_tokens"
        }

        struct Message: Encodable {
            let role: String
            /// Message content — plain text or tool_result blocks depending on the role
            let content: MessageContent

            /// Polymorphic encoding: plain string or array of blocks
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: MessageCodingKeys.self)
                try container.encode(role, forKey: .role)
                switch content {
                case .text(let text):
                    try container.encode(text, forKey: .content)
                case .toolResults(let blocks):
                    try container.encode(blocks, forKey: .content)
                }
            }

            enum MessageCodingKeys: String, CodingKey {
                case role, content
            }
        }

        /// Message content: plain text or tool result blocks
        enum MessageContent {
            case text(String)
            case toolResults([ToolResultBlock])
        }

        /// Tool result block in Anthropic format
        struct ToolResultBlock: Encodable {
            /// Always "tool_result" for the Anthropic format
            let type: String
            let toolUseId: String
            let content: String

            enum CodingKeys: String, CodingKey {
                case type, content
                case toolUseId = "tool_use_id"
            }

            init(toolUseId: String, content: String) {
                self.type = "tool_result"
                self.toolUseId = toolUseId
                self.content = content
            }
        }

        /// Tool definition in Anthropic format
        struct ToolDefinition: Encodable {
            let name: String
            let description: String
            /// Parameter schema in JSON Schema format (key: "input_schema")
            let inputSchema: AITool.AIToolParameters

            enum CodingKeys: String, CodingKey {
                case name, description
                case inputSchema = "input_schema"
            }
        }
    }

    private struct MessagesResponse: Decodable {
        let id: String
        let content: [Content]
        let stopReason: String?

        enum CodingKeys: String, CodingKey {
            case id, content
            case stopReason = "stop_reason"
        }

        /// Content block — can be text or a tool call
        struct Content: Decodable {
            let type: String
            let text: String?
            /// Tool call identifier (type "tool_use")
            let id: String?
            /// Name of the tool to call (type "tool_use")
            let name: String?
            /// Tool arguments as a raw dictionary
            let input: AnthropicInput?
        }

        /// Intermediate representation for tool arguments (dynamic JSON)
        struct AnthropicInput: Decodable {
            let raw: [String: AnthropicValue]

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                raw = try container.decode([String: AnthropicValue].self)
            }

            /// Serializes arguments into a JSON String for AIToolCall
            func toJSONString() -> String {
                let dict = raw.mapValues { $0.toAny() }
                guard let data = try? JSONSerialization.data(withJSONObject: dict),
                      let string = String(data: data, encoding: .utf8) else {
                    return "{}"
                }
                return string
            }
        }

        /// Generic JSON value for deserializing Anthropic tool inputs
        enum AnthropicValue: Decodable {
            case string(String)
            case int(Int)
            case double(Double)
            case bool(Bool)
            case null

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let value = try? container.decode(String.self) {
                    self = .string(value)
                } else if let value = try? container.decode(Int.self) {
                    self = .int(value)
                } else if let value = try? container.decode(Double.self) {
                    self = .double(value)
                } else if let value = try? container.decode(Bool.self) {
                    self = .bool(value)
                } else {
                    self = .null
                }
            }

            func toAny() -> Any {
                switch self {
                case .string(let value): return value
                case .int(let value): return value
                case .double(let value): return value
                case .bool(let value): return value
                case .null: return NSNull()
                }
            }
        }
    }

    private struct StreamEvent: Decodable {
        let type: String
        let delta: Delta?
        let contentBlock: ContentBlock?

        enum CodingKeys: String, CodingKey {
            case type, delta
            case contentBlock = "content_block"
        }

        struct Delta: Decodable {
            let text: String?
        }

        struct ContentBlock: Decodable {
            let text: String?
        }
    }

    // MARK: - Public Methods

    func sendCompletion(messages: [AIMessage]) async throws -> AIMessage {
        let request = try createRequest(messages: messages, tools: nil, stream: false)
        let (data, _) = try await networkClient.execute(request: request)

        let response = try JSONDecoder().decode(MessagesResponse.self, from: data)

        // Extract the first available text block
        guard let textContent = response.content.first(where: { $0.type == "text" })?.text else {
            throw AIError.invalidResponse(statusCode: 200, message: "No content in response")
        }

        return AIMessage(role: .assistant, content: textContent)
    }

    /// Sends messages with available tools — the model may return tool calls
    func sendCompletionWithTools(messages: [AIMessage], tools: [AITool]) async throws -> AIMessageWithTools {
        let request = try createRequest(messages: messages, tools: tools, stream: false)
        let (data, _) = try await networkClient.execute(request: request)

        let response = try JSONDecoder().decode(MessagesResponse.self, from: data)

        // Extract text content (may be absent if the model only calls tools)
        let textContent = response.content.first(where: { $0.type == "text" })?.text ?? ""

        // Extract tool calls from "tool_use" blocks
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
                    let stream = networkClient.stream(request: request)

                    for try await data in stream {
                        let lines = String(data: data, encoding: .utf8)?
                            .components(separatedBy: "\n")
                            .filter { !$0.isEmpty } ?? []

                        for line in lines {
                            guard line.hasPrefix("data: ") else { continue }
                            let jsonString = String(line.dropFirst(6))

                            if let data = jsonString.data(using: .utf8),
                               let event = try? JSONDecoder().decode(StreamEvent.self, from: data) {

                                // Handle the different Anthropic stream event types
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

        // Fail explicitly if the base URL is invalid — never crash in production
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

        // Extract the system message (handled separately by the Anthropic API)
        let systemMessage = messages.first(where: { $0.role == .system })?.content
        let conversationMessages = messages.filter { $0.role != .system }

        // Convert messages to Anthropic format, handling tool results
        let anthropicMessages = conversationMessages.map { message -> MessagesRequest.Message in
            if message.role == .tool, let toolCallId = message.metadata?["tool_call_id"] {
                // Tool results use a structured block content format
                let block = MessagesRequest.ToolResultBlock(
                    toolUseId: toolCallId,
                    content: message.content
                )
                return MessagesRequest.Message(
                    role: "user",
                    content: .toolResults([block])
                )
            }
            return MessagesRequest.Message(
                role: message.role.anthropicName,
                content: .text(message.content)
            )
        }

        // Convert AITool values to Anthropic ToolDefinition if provided
        let toolDefinitions = tools.map { toolArray in
            toolArray.map { tool in
                MessagesRequest.ToolDefinition(
                    name: tool.name,
                    description: tool.description,
                    inputSchema: tool.parameters
                )
            }
        }

        let requestBody = MessagesRequest(
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
