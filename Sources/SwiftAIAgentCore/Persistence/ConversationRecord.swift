import Foundation
import SwiftData

/// Persistent record of a complete conversation
@available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
@Model
public final class ConversationRecord: @unchecked Sendable {
    public var id: UUID
    public var createdAt: Date
    /// Name of the LLM model used (e.g. "gpt-4", "claude-3-opus-20240229")
    public var model: String
    /// Optional system prompt that initiated the conversation
    public var systemPrompt: String?
    /// Associated messages — deleted in cascade with the conversation
    @Relationship(deleteRule: .cascade) public var messages: [MessageRecord]

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        model: String,
        systemPrompt: String? = nil,
        messages: [MessageRecord] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.model = model
        self.systemPrompt = systemPrompt
        self.messages = messages
    }
}
