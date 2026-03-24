import Foundation
import SwiftData

/// Enregistrement persistant d'une conversation complète
@available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
@Model
public final class ConversationRecord {
    public var id: UUID
    public var createdAt: Date
    /// Nom du modèle LLM utilisé (ex: "gpt-4", "claude-3-opus-20240229")
    public var model: String
    /// Prompt système optionnel qui a initié la conversation
    public var systemPrompt: String?
    /// Messages associés — supprimés en cascade avec la conversation
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
