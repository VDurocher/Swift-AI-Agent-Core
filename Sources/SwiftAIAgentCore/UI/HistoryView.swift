import SwiftUI
import SwiftData

/// Main conversation history view.
/// Requires a ModelContainer in the SwiftUI environment:
/// `.modelContainer(myContainer)` on an ancestor view.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
public struct HistoryView: View {
    @Query(sort: \ConversationRecord.createdAt, order: .reverse)
    private var conversations: [ConversationRecord]

    @Environment(\.modelContext) private var modelContext

    /// Conversation selected for deletion confirmation
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
            .navigationTitle("History")
        }
        .confirmationDialog(
            "Delete this conversation?",
            isPresented: .init(
                get: { conversationPendingDelete != nil },
                set: { if !$0 { conversationPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let target = conversationPendingDelete {
                    deleteConversation(target)
                    conversationPendingDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                conversationPendingDelete = nil
            }
        }
    }

    // MARK: - Subviews

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
            "No Conversations",
            systemImage: "bubble.left.and.bubble.right",
            description: Text("Your conversations will appear here after your first exchange.")
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

// MARK: - Conversation Row

@available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
private struct ConversationRowView: View {
    let conversation: ConversationRecord

    private var lastMessagePreview: String {
        guard let lastMessage = conversation.messages
            .sorted(by: { $0.timestamp < $1.timestamp })
            .last
        else { return "No messages" }
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
