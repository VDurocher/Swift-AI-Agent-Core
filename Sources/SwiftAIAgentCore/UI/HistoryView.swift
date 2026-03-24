import SwiftUI
import SwiftData

/// Vue principale de l'historique des conversations.
/// Nécessite un ModelContainer dans l'environnement SwiftUI :
/// `.modelContainer(myContainer)` sur un ancêtre de la vue.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
public struct HistoryView: View {
    @Query(sort: \ConversationRecord.createdAt, order: .reverse)
    private var conversations: [ConversationRecord]

    @Environment(\.modelContext) private var modelContext

    /// Conversation sélectionnée pour la confirmation de suppression
    @State private var conversationPendingDelete: ConversationRecord?

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if conversations.isEmpty {
                    emptyStateView
                } else {
                    conversationList
                }
            }
            .navigationTitle("Historique")
        }
        .confirmationDialog(
            "Supprimer cette conversation ?",
            isPresented: .init(
                get: { conversationPendingDelete != nil },
                set: { if !$0 { conversationPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                if let target = conversationPendingDelete {
                    deleteConversation(target)
                    conversationPendingDelete = nil
                }
            }
            Button("Annuler", role: .cancel) {
                conversationPendingDelete = nil
            }
        }
    }

    // MARK: - Sous-vues

    private var conversationList: some View {
        List {
            ForEach(conversations) { conversation in
                NavigationLink(value: conversation) {
                    ConversationRowView(conversation: conversation)
                }
            }
            .onDelete(perform: requestDelete)
        }
        .navigationDestination(for: ConversationRecord.self) { conversation in
            ConversationDetailView(conversation: conversation)
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            "Aucune conversation",
            systemImage: "bubble.left.and.bubble.right",
            description: Text("Vos conversations apparaîtront ici après votre premier échange.")
        )
    }

    // MARK: - Actions

    private func requestDelete(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        conversationPendingDelete = conversations[index]
    }

    private func deleteConversation(_ conversation: ConversationRecord) {
        modelContext.delete(conversation)
        try? modelContext.save()
    }
}

// MARK: - Cellule de conversation

@available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
private struct ConversationRowView: View {
    let conversation: ConversationRecord

    private var lastMessagePreview: String {
        guard let lastMessage = conversation.messages
            .sorted(by: { $0.timestamp < $1.timestamp })
            .last
        else { return "Aucun message" }
        let content = lastMessage.content
        return content.count > 60 ? String(content.prefix(60)) + "…" : content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(conversation.model)
                    .font(.headline)
                Spacer()
                Text(conversation.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(lastMessagePreview)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("\(conversation.messages.count) message(s)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
