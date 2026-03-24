import Foundation
import SwiftData

/// Gestionnaire de l'historique des conversations, confiné à son propre executor SwiftData.
/// Utilise @ModelActor pour garantir la thread-safety en Swift 6 strict concurrency.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
@ModelActor
public actor HistoryManager {

    // MARK: - Écriture

    /// Sauvegarde une conversation complète (messages envoyés + réponse de l'agent)
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

        // Insérer le record principal avant de configurer les relations
        modelContext.insert(record)

        // Persister tous les messages + la réponse dans l'ordre chronologique
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

    /// Supprime une conversation par son identifiant
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

    // MARK: - Lecture

    /// Charge toutes les conversations, triées par date décroissante
    public func loadConversations() throws -> [ConversationRecord] {
        let descriptor = FetchDescriptor<ConversationRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Charge les N derniers messages de la conversation la plus récente,
    /// convertis en AIMessage pour alimenter le contexte de l'agent
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

    /// Convertit un ConversationRecord en tableau de AIMessage
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
