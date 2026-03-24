import Foundation

// Types pour le function calling / tool use multimodal
// Compatible OpenAI tools format et Anthropic tools format

/// Décrit un outil (fonction) que l'agent peut appeler
public struct AITool: Sendable, Encodable, Hashable {
    public let name: String
    public let description: String
    public let parameters: AIToolParameters

    public init(name: String, description: String, parameters: AIToolParameters) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }

    /// Paramètres de l'outil au format JSON Schema
    public struct AIToolParameters: Sendable, Encodable, Hashable {
        /// Toujours "object" selon la spécification JSON Schema
        public let type: String
        public let properties: [String: AIToolProperty]
        public let required: [String]

        public init(properties: [String: AIToolProperty], required: [String] = []) {
            self.type = "object"
            self.properties = properties
            self.required = required
        }
    }

    /// Propriété individuelle dans le JSON Schema
    public struct AIToolProperty: Sendable, Encodable, Hashable {
        /// Type JSON Schema : "string", "integer", "boolean", "number", "array"
        public let type: String
        public let description: String
        /// Valeurs possibles si la propriété est de type enum
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
