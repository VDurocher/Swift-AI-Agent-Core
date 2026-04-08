import SwiftUI
import SwiftData

/// Detail view for a conversation, displaying all messages with their role.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
public struct ConversationDetailView: View {
    let conversation: ConversationRecord

    private var sortedMessages: [MessageRecord] {
        conversation.messages.sorted { $0.timestamp < $1.timestamp }
    }

    public var body: some View {
        List {
            // Conversation metadata
            Section {
                LabeledContent("Model", value: conversation.model)
                LabeledContent("Date", value: conversation.createdAt.formatted(date: .long, time: .shortened))
                LabeledContent("Messages", value: "\(conversation.messages.count)")
                if let systemPrompt = conversation.systemPrompt {
                    LabeledContent("System Prompt") {
                        Text(systemPrompt)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Information")
            }

            // Messages in chronological order
            Section {
                ForEach(sortedMessages) { message in
                    MessageRowView(message: message)
                }
            } header: {
                Text("Messages")
            }
        }
        .navigationTitle("Conversation")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Message Row

@available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
private struct MessageRowView: View {
    let message: MessageRecord

    private var roleLabel: String {
        switch message.role {
        case "user": return "User"
        case "assistant": return "Assistant"
        case "system": return "System"
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
