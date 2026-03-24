import SwiftUI
import SwiftAIAgentCore

/// Bulle de message avec style adapté au rôle (user / assistant / system)
struct MessageBubble: View {

    let message: AIMessage

    // Formateur de date partagé pour les timestamps
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    var body: some View {
        switch message.role {
        case .user:
            userBubble
        case .assistant:
            assistantBubble
        case .system:
            systemBubble
        }
    }

    // MARK: - Bulle utilisateur (droite, accent color)

    private var userBubble: some View {
        HStack(alignment: .bottom) {
            Spacer(minLength: 60)
            VStack(alignment: .trailing, spacing: 4) {
                Text(message.content)
                    .textSelection(.enabled)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.accentColor)
                    )
                timestampLabel
                    .padding(.trailing, 4)
            }
        }
    }

    // MARK: - Bulle assistant (gauche, fond secondaire)

    private var assistantBubble: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                // Rendu Markdown natif via Text (Swift 5.5+)
                Text(LocalizedStringKey(message.content))
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.windowBackgroundColor))
                            .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                    )
                timestampLabel
                    .padding(.leading, 4)
            }
            Spacer(minLength: 60)
        }
    }

    // MARK: - Message système (centré, style caption)

    private var systemBubble: some View {
        HStack {
            Spacer()
            Text(message.content)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(.tertiary)
                )
            Spacer()
        }
    }

    // MARK: - Timestamp

    private var timestampLabel: some View {
        Text(Self.timeFormatter.string(from: message.timestamp))
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }
}
