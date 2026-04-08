import Foundation

// Types for function calling / multimodal tool use
// Compatible with OpenAI tools format and Anthropic tools format

/// Describes a tool (function) that the agent can call
public struct AITool: Sendable, Encodable, Hashable {
    public let name: String
    public let description: String
    public let parameters: AIToolParameters

    public init(name: String, description: String, parameters: AIToolParameters) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }

    /// Tool parameters in JSON Schema format
    public struct AIToolParameters: Sendable, Encodable, Hashable {
        /// Always "object" per JSON Schema specification
        public let type: String
        public let properties: [String: AIToolProperty]
        public let required: [String]

        public init(properties: [String: AIToolProperty], required: [String] = []) {
            self.type = "object"
            self.properties = properties
            self.required = required
        }
    }

    /// Individual property in the JSON Schema
    public struct AIToolProperty: Sendable, Encodable, Hashable {
        /// JSON Schema type: "string", "integer", "boolean", "number", "array"
        public let type: String
        public let description: String
        /// Allowed values if the property is an enum type
        public let enumValues: [String]?

        public init(type: String, description: String, enumValues: [String]? = nil) {
            self.type = type
            self.description = description
            self.enumValues = enumValues
        }

        enum CodingKeys: String, CodingKey {
            case type, description
            case enumValues = "enum"
        }
    }
}
