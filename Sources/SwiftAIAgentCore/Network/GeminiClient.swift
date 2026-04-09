import Foundation

/// Google Gemini API client
/// API key is passed as a query parameter, not a header
actor GeminiClient: Sendable {
    private let networkClient: NetworkClient
    private let configuration: AIConfiguration

    init(configuration: AIConfiguration) {
        self.configuration = configuration
        self.networkClient = NetworkClient(retryPolicy: configuration.retryPolicy)
    }

    // MARK: - Public Methods

    func sendCompletion(messages: [AIMessage]) async throws -> AIMessage {
        let request = try buildRequest(messages: messages, tools: nil, stream: false, jsonMode: false)
        let (data, _) = try await networkClient.execute(request: request)
        return try decodeResponse(from: data)
    }

    func sendCompletionJSON(messages: [AIMessage]) async throws -> AIMessage {
        let request = try buildRequest(messages: messages, tools: nil, stream: false, jsonMode: true)
        let (data, _) = try await networkClient.execute(request: request)
        return try decodeResponse(from: data)
    }

    func sendCompletionWithTools(messages: [AIMessage], tools: [AITool]) async throws -> AIMessageWithTools {
        let request = try buildRequest(messages: messages, tools: tools, stream: false, jsonMode: false)
        let (data, _) = try await networkClient.execute(request: request)
        let response = try JSONDecoder().decode(GenerateContentResponse.self, from: data)

        guard let candidate = response.candidates.first else {
            throw AIError.invalidResponse(statusCode: 200, message: "No candidates in response")
        }

        var text = ""
        var toolCalls: [AIToolCall] = []

        for part in candidate.content.parts {
            if let t = part.text { text += t }
            if let call = part.functionCall {
                let args = serializeArgs(call.args)
                toolCalls.append(AIToolCall(id: UUID().uuidString, name: call.name, arguments: args))
            }
        }

        return AIMessageWithTools(message: AIMessage(role: .assistant, content: text), toolCalls: toolCalls)
    }

    func streamCompletion(messages: [AIMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try self.buildRequest(messages: messages, tools: nil, stream: true, jsonMode: false)
                    let stream = await self.networkClient.stream(request: request)

                    for try await data in stream {
                        let lines = String(data: data, encoding: .utf8)?
                            .components(separatedBy: "\n").filter { !$0.isEmpty } ?? []
                        for line in lines {
                            guard line.hasPrefix("data: ") else { continue }
                            let json = String(line.dropFirst(6))
                            guard let chunkData = json.data(using: .utf8),
                                  let response = try? JSONDecoder().decode(GenerateContentResponse.self, from: chunkData) else { continue }
                            for part in response.candidates.first?.content.parts ?? [] {
                                if let text = part.text { continuation.yield(text) }
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

    private func decodeResponse(from data: Data) throws -> AIMessage {
        let response = try JSONDecoder().decode(GenerateContentResponse.self, from: data)
        guard let candidate = response.candidates.first else {
            throw AIError.invalidResponse(statusCode: 200, message: "No candidates in response")
        }
        let text = candidate.content.parts.compactMap { $0.text }.joined()
        return AIMessage(role: .assistant, content: text)
    }

    private func buildRequest(messages: [AIMessage], tools: [AITool]?, stream: Bool, jsonMode: Bool) throws -> URLRequest {
        try configuration.validate()

        let method = stream ? "streamGenerateContent" : "generateContent"
        var components = URLComponents(string: "\(configuration.model.provider.baseURL)/models/\(configuration.model.name):\(method)")
        var queryItems = [URLQueryItem(name: "key", value: configuration.apiKey)]
        if stream { queryItems.append(URLQueryItem(name: "alt", value: "sse")) }
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw AIError.invalidContext("Invalid Gemini endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = configuration.timeout

        // Extract system message
        let systemInstruction = messages.first(where: { $0.role == .system }).map { msg in
            SystemInstruction(parts: [GeminiPart(text: msg.content)])
        }
        let conversationMessages = messages.filter { $0.role != .system }

        // Encode tool definitions
        let geminiTools = tools.map { toolArray in
            [GeminiTool(functionDeclarations: toolArray.map { FunctionDeclaration(from: $0) })]
        }

        let config = GenerationConfig(
            temperature: configuration.temperature,
            maxOutputTokens: configuration.maxResponseTokens,
            responseMimeType: jsonMode ? "application/json" : "text/plain"
        )

        let body = GenerateContentRequest(
            contents: conversationMessages.map { encodeMessage($0) },
            systemInstruction: systemInstruction,
            generationConfig: config,
            tools: geminiTools
        )

        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func encodeMessage(_ message: AIMessage) -> GeminiContent {
        let role = message.role == .assistant ? "model" : "user"

        // Tool result messages — Gemini expects the function name (not the call ID)
        if message.role == .tool,
           let functionName = message.metadata?["tool_name"] ?? message.metadata?["tool_call_id"] {
            let part = GeminiPart(functionResponse: FunctionResponse(
                name: functionName,
                response: GeminiResponsePayload(content: message.content)
            ))
            return GeminiContent(role: "user", parts: [part])
        }

        // Assistant messages with tool calls
        if message.role == .assistant, let calls = message.toolCalls, !calls.isEmpty {
            var parts: [GeminiPart] = []
            if !message.content.isEmpty { parts.append(GeminiPart(text: message.content)) }
            for call in calls {
                let rawArgs = call.decodeArguments() ?? [:]
                let args = rawArgs.mapValues { GeminiScalar.from($0) }
                parts.append(GeminiPart(functionCall: FunctionCall(name: call.name, args: args)))
            }
            return GeminiContent(role: "model", parts: parts)
        }

        var parts: [GeminiPart] = []

        // Vision: encode images as inlineData
        if let images = message.images {
            for image in images {
                switch image {
                case .data(let bytes, let mime):
                    parts.append(GeminiPart(inlineData: InlineData(mimeType: mime, data: bytes.base64EncodedString())))
                case .url:
                    break // Gemini inline data only; URL images not supported in this client
                }
            }
        }

        parts.append(GeminiPart(text: message.content))
        return GeminiContent(role: role, parts: parts)
    }

    private func serializeArgs(_ args: [String: GeminiArgValue]?) -> String {
        guard let args else { return "{}" }
        let scalars = args.mapValues { GeminiScalar.from($0) }
        guard let data = try? JSONEncoder().encode(scalars),
              let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }
}

// MARK: - Request Models

private struct GenerateContentRequest: Encodable {
    let contents: [GeminiContent]
    let systemInstruction: SystemInstruction?
    let generationConfig: GenerationConfig
    let tools: [GeminiTool]?
}

private struct GeminiContent: Encodable {
    let role: String
    let parts: [GeminiPart]
}

private struct GeminiPart: Encodable {
    let text: String?
    let inlineData: InlineData?
    let functionCall: FunctionCall?
    let functionResponse: FunctionResponse?

    init(text: String) { self.text = text; self.inlineData = nil; self.functionCall = nil; self.functionResponse = nil }
    init(inlineData: InlineData) { self.text = nil; self.inlineData = inlineData; self.functionCall = nil; self.functionResponse = nil }
    init(functionCall: FunctionCall) { self.text = nil; self.inlineData = nil; self.functionCall = functionCall; self.functionResponse = nil }
    init(functionResponse: FunctionResponse) { self.text = nil; self.inlineData = nil; self.functionCall = nil; self.functionResponse = functionResponse }

    // Gemini REST API v1 uses camelCase throughout
    enum CodingKeys: String, CodingKey {
        case text
        case inlineData       // "inlineData"
        case functionCall     // "functionCall"
        case functionResponse // "functionResponse"
    }
}

private struct InlineData: Encodable {
    let mimeType: String
    let data: String

    enum CodingKeys: String, CodingKey {
        case mimeType = "mime_type"
        case data
    }
}

private struct FunctionCall: Encodable {
    let name: String
    let args: [String: GeminiScalar]
}

private struct FunctionResponse: Encodable {
    let name: String
    let response: GeminiResponsePayload
}

private struct GeminiResponsePayload: Encodable {
    let content: String
}

private struct SystemInstruction: Encodable {
    let parts: [GeminiPart]
}

private struct GenerationConfig: Encodable {
    let temperature: Double
    let maxOutputTokens: Int
    let responseMimeType: String

    enum CodingKeys: String, CodingKey {
        case temperature
        case maxOutputTokens = "maxOutputTokens"
        case responseMimeType = "responseMimeType"
    }
}

private struct GeminiTool: Encodable {
    let functionDeclarations: [FunctionDeclaration]
}

private struct FunctionDeclaration: Encodable {
    let name: String
    let description: String
    let parameters: AITool.AIToolParameters

    init(from tool: AITool) {
        self.name = tool.name
        self.description = tool.description
        self.parameters = tool.parameters
    }
}

// MARK: - Response Models

private struct GenerateContentResponse: Decodable {
    let candidates: [Candidate]

    struct Candidate: Decodable {
        let content: Content
        let finishReason: String? // Gemini returns "finishReason" (camelCase) — matches Swift default
    }

    struct Content: Decodable {
        let parts: [Part]
        let role: String?
    }

    struct Part: Decodable {
        let text: String?
        let functionCall: FunctionCallResponse? // Gemini returns "functionCall" (camelCase)
    }

    struct FunctionCallResponse: Decodable {
        let name: String
        let args: [String: GeminiArgValue]?
    }
}

/// Scalar JSON value for encoding Gemini function call arguments (outbound)
private enum GeminiScalar: Codable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    static func from(_ any: Any) -> GeminiScalar {
        switch any {
        case let v as String: return .string(v)
        case let v as Bool: return .bool(v)   // must precede Int/Double — NSNumber ambiguity
        case let v as Int: return .number(Double(v))
        case let v as Double: return .number(v)
        default: return .null
        }
    }

    static func from(_ value: GeminiArgValue) -> GeminiScalar {
        switch value {
        case .string(let v): return .string(v)
        case .number(let v): return .number(v)
        case .bool(let v): return .bool(v)
        case .null: return .null
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
}

/// Generic JSON value for Gemini function call arguments
enum GeminiArgValue: Decodable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else { self = .null }
    }
}
