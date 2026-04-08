import Foundation

// MARK: - Anthropic API Request Models

struct AnthropicMessagesRequest: Encodable {
    let model: String
    let messages: [AnthropicMessage]
    let maxTokens: Int
    let temperature: Double
    let system: String?
    let stream: Bool
    /// Available tools in Anthropic format (optional)
    let tools: [AnthropicToolDefinition]?

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, system, stream, tools
        case maxTokens = "max_tokens"
    }
}

struct AnthropicMessage: Encodable {
    let role: String
    /// Message content — plain text or tool_result blocks depending on the role
    let content: AnthropicMessageContent

    /// Polymorphic encoding: plain string or array of blocks
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        switch content {
        case .text(let text):
            try container.encode(text, forKey: .content)
        case .toolResults(let blocks):
            try container.encode(blocks, forKey: .content)
        }
    }

    enum CodingKeys: String, CodingKey {
        case role, content
    }
}

/// Message content: plain text or tool result blocks
enum AnthropicMessageContent {
    case text(String)
    case toolResults([AnthropicToolResultBlock])
}

/// Tool result block in Anthropic format
struct AnthropicToolResultBlock: Encodable {
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
struct AnthropicToolDefinition: Encodable {
    let name: String
    let description: String
    /// Parameter schema in JSON Schema format (key: "input_schema")
    let inputSchema: AITool.AIToolParameters

    enum CodingKeys: String, CodingKey {
        case name, description
        case inputSchema = "input_schema"
    }
}

// MARK: - Anthropic API Response Models

struct AnthropicMessagesResponse: Decodable {
    let id: String
    let content: [ContentBlock]
    let stopReason: String?

    enum CodingKeys: String, CodingKey {
        case id, content
        case stopReason = "stop_reason"
    }

    /// Content block — can be text or a tool call
    struct ContentBlock: Decodable {
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

// MARK: - Anthropic Stream Models

struct AnthropicStreamEvent: Decodable {
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
