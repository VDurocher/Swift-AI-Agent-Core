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
        let request = try buildRequest(messages: messages, tools: nil, stream: false)
        let (data, _) = try await networkClient.execute(request: request)
        return try decodeTextResponse(from: data)
    }

    func sendCompletionWithTools(messages: [AIMessage], tools: [AITool]) async throws -> AIMessageWithTools {
        let request = try buildRequest(messages: messages, tools: tools, stream: false)
        let (data, _) = try await networkClient.execute(request: request)

        let response = try JSONDecoder().decode(MessagesResponse.self, from: data)
        let text = response.content.first(where: { $0.type == "text" })?.text ?? ""

        let toolCalls: [AIToolCall] = response.content.compactMap { block in
            guard block.type == "tool_use", let id = block.id, let name = block.name else { return nil }
            return AIToolCall(id: id, name: name, arguments: block.input?.toJSONString() ?? "{}")
        }

        return AIMessageWithTools(message: AIMessage(role: .assistant, content: text), toolCalls: toolCalls)
    }

    func streamCompletion(messages: [AIMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try self.buildRequest(messages: messages, tools: nil, stream: true)
                    let stream = await self.networkClient.stream(request: request)

                    for try await data in stream {
                        let lines = String(data: data, encoding: .utf8)?
                            .components(separatedBy: "\n").filter { !$0.isEmpty } ?? []
                        for line in lines {
                            guard line.hasPrefix("data: ") else { continue }
                            let json = String(line.dropFirst(6))
                            guard let eventData = json.data(using: .utf8),
                                  let event = try? JSONDecoder().decode(StreamEvent.self, from: eventData) else { continue }

                            switch event.type {
                            case "content_block_delta":
                                if let text = event.delta?.text { continuation.yield(text) }
                            case "message_stop":
                                continuation.finish(); return
                            default:
                                break
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

    private func decodeTextResponse(from data: Data) throws -> AIMessage {
        let response = try JSONDecoder().decode(MessagesResponse.self, from: data)
        guard let text = response.content.first(where: { $0.type == "text" })?.text else {
            throw AIError.invalidResponse(statusCode: 200, message: "No content in response")
        }
        return AIMessage(role: .assistant, content: text)
    }

    private func buildRequest(messages: [AIMessage], tools: [AITool]?, stream: Bool) throws -> URLRequest {
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

        // Feature 5: Add prompt caching beta header when any message opts in
        let usesCaching = messages.contains { $0.cacheControl }
        if usesCaching {
            request.setValue("prompt-caching-2024-07-31", forHTTPHeaderField: "anthropic-beta")
        }

        let systemMessages = messages.filter { $0.role == .system }
        let conversationMessages = messages.filter { $0.role != .system }

        // Build system content — supports caching on individual system messages
        let systemContent: SystemContent? = systemMessages.isEmpty ? nil : {
            if systemMessages.allSatisfy({ !$0.cacheControl }) {
                // Simple string format when no caching needed
                return .text(systemMessages.map { $0.content }.joined(separator: "\n"))
            }
            // Block format required for cache_control
            let blocks = systemMessages.map { msg in
                SystemBlock(text: msg.content, cached: msg.cacheControl)
            }
            return .blocks(blocks)
        }()

        let anthropicMessages = conversationMessages.map { encodeMessage($0) }

        let toolDefs = tools.map { $0.map { ToolDefinition(from: $0) } }

        let body = MessagesRequest(
            model: configuration.model.name,
            messages: anthropicMessages,
            maxTokens: configuration.maxResponseTokens,
            temperature: configuration.temperature,
            system: systemContent,
            stream: stream,
            tools: toolDefs
        )

        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    /// Converts an AIMessage into the Anthropic wire format
    private func encodeMessage(_ message: AIMessage) -> OutboundMessage {
        // Tool result messages become user messages with tool_result blocks
        if message.role == .tool, let callId = message.metadata?["tool_call_id"] {
            return OutboundMessage(role: "user", blocks: [.toolResult(id: callId, content: message.content)])
        }

        // Assistant messages with tool calls become mixed content blocks
        if message.role == .assistant, let calls = message.toolCalls, !calls.isEmpty {
            var blocks: [ContentBlock] = []
            if !message.content.isEmpty {
                blocks.append(.text(message.content, cached: false))
            }
            for call in calls {
                let input = call.decodeArguments().map { dict in
                    dict.mapValues { AnthropicScalar.from($0) }
                } ?? [:]
                blocks.append(.toolUse(id: call.id, name: call.name, input: input))
            }
            return OutboundMessage(role: "assistant", blocks: blocks)
        }

        // Messages with images use block content
        if let images = message.images, !images.isEmpty {
            var blocks: [ContentBlock] = []
            for image in images {
                blocks.append(.image(image, cached: message.cacheControl))
            }
            blocks.append(.text(message.content, cached: message.cacheControl))
            return OutboundMessage(role: message.role.anthropicName, blocks: blocks)
        }

        // Simple text message (possibly cached)
        if message.cacheControl {
            return OutboundMessage(role: message.role.anthropicName, blocks: [.text(message.content, cached: true)])
        }

        return OutboundMessage(role: message.role.anthropicName, text: message.content)
    }
}

// MARK: - Request Models

private struct MessagesRequest: Encodable {
    let model: String
    let messages: [OutboundMessage]
    let maxTokens: Int
    let temperature: Double
    let system: SystemContent?
    let stream: Bool
    let tools: [ToolDefinition]?

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, system, stream, tools
        case maxTokens = "max_tokens"
    }
}

private enum SystemContent: Encodable {
    case text(String)
    case blocks([SystemBlock])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let t): try container.encode(t)
        case .blocks(let blocks): try container.encode(blocks)
        }
    }
}

private struct SystemBlock: Encodable {
    let type = "text"
    let text: String
    let cacheControl: CacheControl?

    init(text: String, cached: Bool) {
        self.text = text
        self.cacheControl = cached ? CacheControl() : nil
    }

    enum CodingKeys: String, CodingKey {
        case type, text
        case cacheControl = "cache_control"
    }
}

private struct CacheControl: Encodable {
    let type = "ephemeral"
}

/// Anthropic message with polymorphic content (string or blocks array)
private struct OutboundMessage: Encodable {
    let role: String
    private let textContent: String?
    private let blocks: [ContentBlock]?

    init(role: String, text: String) {
        self.role = role
        self.textContent = text
        self.blocks = nil
    }

    init(role: String, blocks: [ContentBlock]) {
        self.role = role
        self.textContent = nil
        self.blocks = blocks
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(role, forKey: .role)
        if let blocks {
            try c.encode(blocks, forKey: .content)
        } else {
            try c.encode(textContent ?? "", forKey: .content)
        }
    }

    enum Keys: String, CodingKey { case role, content }
}

private enum ContentBlock: Encodable {
    case text(String, cached: Bool)
    case image(AIImageContent, cached: Bool)
    case toolResult(id: String, content: String)
    case toolUse(id: String, name: String, input: [String: AnthropicScalar])

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: BlockKeys.self)
        switch self {
        case .text(let text, let cached):
            try c.encode("text", forKey: .type)
            try c.encode(text, forKey: .text)
            if cached { try c.encode(CacheControl(), forKey: .cacheControl) }

        case .image(let img, let cached):
            try c.encode("image", forKey: .type)
            switch img {
            case .url(let url):
                try c.encode(["type": "url", "url": url.absoluteString], forKey: .source)
            case .data(let bytes, let mime):
                try c.encode(["type": "base64", "media_type": mime, "data": bytes.base64EncodedString()], forKey: .source)
            }
            if cached { try c.encode(CacheControl(), forKey: .cacheControl) }

        case .toolResult(let id, let content):
            try c.encode("tool_result", forKey: .type)
            try c.encode(id, forKey: .toolUseId)
            try c.encode(content, forKey: .content)

        case .toolUse(let id, let name, let input):
            try c.encode("tool_use", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(name, forKey: .name)
            try c.encode(input, forKey: .input)
        }
    }

    enum BlockKeys: String, CodingKey {
        case type, text, source, content, id, name, input
        case cacheControl = "cache_control"
        case toolUseId = "tool_use_id"
    }
}

/// Scalar JSON value used for tool_use input encoding
enum AnthropicScalar: Codable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    static func from(_ any: Any) -> AnthropicScalar {
        switch any {
        case let v as String: return .string(v)
        case let v as Bool: return .bool(v)   // must precede Int/Double — NSNumber ambiguity
        case let v as Int: return .int(v)
        case let v as Double: return .double(v)
        default: return .null
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode(Int.self) { self = .int(v) }
        else if let v = try? c.decode(Double.self) { self = .double(v) }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
}

private struct ToolDefinition: Encodable {
    let name: String
    let description: String
    let inputSchema: AITool.AIToolParameters

    enum CodingKeys: String, CodingKey {
        case name, description
        case inputSchema = "input_schema"
    }

    init(from tool: AITool) {
        self.name = tool.name
        self.description = tool.description
        self.inputSchema = tool.parameters
    }
}

// MARK: - Response Models

private struct MessagesResponse: Decodable {
    let content: [ContentBlock]
    let stopReason: String?

    enum CodingKeys: String, CodingKey {
        case content
        case stopReason = "stop_reason"
    }

    struct ContentBlock: Decodable {
        let type: String
        let text: String?
        let id: String?
        let name: String?
        let input: AnthropicInput?
    }

    struct AnthropicInput: Decodable {
        let raw: [String: AnthropicScalar]

        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            raw = try c.decode([String: AnthropicScalar].self)
        }

        func toJSONString() -> String {
            var dict: [String: Any] = [:]
            for (key, value) in raw {
                switch value {
                case .string(let v): dict[key] = v
                case .int(let v): dict[key] = v
                case .double(let v): dict[key] = v
                case .bool(let v): dict[key] = v
                case .null: dict[key] = NSNull()
                }
            }
            guard let data = try? JSONSerialization.data(withJSONObject: dict),
                  let str = String(data: data, encoding: .utf8) else { return "{}" }
            return str
        }
    }
}

private struct StreamEvent: Decodable {
    let type: String
    let delta: Delta?

    struct Delta: Decodable {
        let text: String?
    }
}
