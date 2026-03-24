import SwiftUI
import SwiftData

/// Vue détaillée d'une conversation, affichant tous les messages avec leur rôle.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
public struct ConversationDetailView: View {
    let conversation: ConversationRecord

    private var sortedMessages: [MessageRecord] {
        conversation.messages.sorted { $0.timestamp < $1.timestamp }
    }

    public var body: some View {
        List {
            // Métadonnées de la conversation
            Section {
                LabeledContent("Modèle", value: conversation.model)
                LabeledContent("Date", value: conversation.createdAt.formatted(date: .long, time: .shortened))
                LabeledContent("Messages", value: "\(conversation.messages.count)")
                if let systemPrompt = conversation.systemPrompt {
                    LabeledContent("Prompt système") {
                        Text(systemPrompt)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Informations")
            }

            // Liste des messages dans l'ordre chronologique
            Section {
                ForEach(sortedMessages) { message in
                    MessageRowView(message: message)
                }
            } header: {
                Text("Messages")
            }
        }
        .navigationTitle("Conversation")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Cellule de message

@available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
private struct MessageRowView: View {
    let message: MessageRecord

    private var roleLabel: String {
        switch message.role {
        case "user": return "Utilisateur"
        case "assistant": return "Assistant"
        case "system": return "Système"
        default: return message.role.capitalized
        }
    }

    private var roleColor: Color {
        switch message.role {
        case "user": return .blue
        case "assistant": return .green
        case "system": return .orange
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(roleLabel)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(roleColor)
                Spacer()
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(message.content)
                .font(.body)
        }
        .padding(.vertical, 4)
    }
}
