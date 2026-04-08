import Foundation
import SwiftData

/// Conversation history manager, confined to its own SwiftData executor.
/// Uses @ModelActor to guarantee thread safety under Swift 6 strict concurrency.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
@ModelActor
public actor HistoryManager {

    // MARK: - Write

    /// Saves a complete conversation (sent messages + agent response)
    public func saveConversation(
        messages: [AIMessage],
        response: AIMessage,
        modelName: String
    ) throws {
        let systemPrompt = messages.first(where: { $0.role == .system })?.content
        let record = ConversationRecord(
            model: modelName,
            systemPrompt: systemPrompt
        )

        // Insert the main record before setting up relationships
        modelContext.insert(record)

        // Persist all messages + the response in chronological order
        let allMessages = messages + [response]
        for message in allMessages {
            let messageRecord = MessageRecord(
                role: message.role.rawValue,
                content: message.content,
                timestamp: message.timestamp
            )
            modelContext.insert(messageRecord)
            record.messages.append(messageRecord)
        }

        try modelContext.save()
    }

    /// Deletes a conversation by its identifier
    public func deleteConversation(id: UUID) throws {
        let targetID = id
        let descriptor = FetchDescriptor<ConversationRecord>(
            predicate: #Predicate { $0.id == targetID }
        )
        let records = try modelContext.fetch(descriptor)
        for record in records {
            modelContext.delete(record)
        }
        try modelContext.save()
    }

    // MARK: - Read

    /// Loads all conversations sorted by descending date
    public func loadConversations() throws -> [ConversationRecord] {
        let descriptor = FetchDescriptor<ConversationRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Loads the last N messages from the most recent conversation,
    /// converted to AIMessage to seed the agent's context
    public func loadPreviousContext(limit: Int = 20) throws -> [AIMessage] {
        var descriptor = FetchDescriptor<ConversationRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        guard let lastConversation = try modelContext.fetch(descriptor).first else {
            return []
        }

        return lastConversation.messages
            .sorted { $0.timestamp < $1.timestamp }
            .suffix(limit)
            .compactMap { record in
                guard let role = AIRole(rawValue: record.role) else { return nil }
                return AIMessage(
                    role: role,
                    content: record.content,
                    timestamp: record.timestamp
                )
            }
    }

    /// Converts a ConversationRecord into an array of AIMessage
    public func conversationToMessages(_ record: ConversationRecord) -> [AIMessage] {
        record.messages
            .sorted { $0.timestamp < $1.timestamp }
            .compactMap { messageRecord in
                guard let role = AIRole(rawValue: messageRecord.role) else { return nil }
                return AIMessage(
                    role: role,
                    content: messageRecord.content,
                    timestamp: messageRecord.timestamp
                )
            }
    }
}
