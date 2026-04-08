import Foundation

/// Tool call requested by the model in a response
public struct AIToolCall: Sendable, Codable, Hashable {
    /// Unique call identifier (e.g. "call_abc123"), required to match the result
    public let id: String
    /// Name of the tool to call
    public let name: String
    /// Tool arguments encoded as a JSON String
    public let arguments: String

    public init(id: String, name: String, arguments: String) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }

    /// Attempts to decode arguments into a key/value dictionary
    /// Returns nil if the JSON is invalid or does not represent an object
    public func decodeArguments() -> [String: Any]? {
        guard let data = arguments.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}

/// Result of a tool call provided by the host application
public struct AIToolResult: Sendable {
    /// Identifier of the corresponding tool call — must match AIToolCall.id
    public let toolCallId: String
    /// Execution result as plain text
    public let content: String

    public init(toolCallId: String, content: String) {
        self.toolCallId = toolCallId
        self.content = content
    }
}

/// Agent response that may contain text and/or tool calls
public struct AIMessageWithTools: Sendable {
    /// Text message from the agent (content may be empty if the model only calls tools)
    public let message: AIMessage
    /// Tool calls requested by the model (empty for pure text responses)
    public let toolCalls: [AIToolCall]

    /// Indicates whether the application must execute tools before continuing the conversation
    public var requiresToolExecution: Bool { !toolCalls.isEmpty }

    public init(message: AIMessage, toolCalls: [AIToolCall] = []) {
        self.message = message
        self.toolCalls = toolCalls
    }
}
