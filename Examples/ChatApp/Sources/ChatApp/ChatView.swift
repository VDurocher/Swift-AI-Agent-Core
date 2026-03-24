import SwiftUI
import SwiftAIAgentCore

/// Vue principale du chat — messages, zone de saisie et boutons d'envoi
struct ChatView: View {

    var viewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            messagesArea
            Divider()
            inputArea
        }
        .navigationTitle(viewModel.currentSession?.title ?? "Chat")
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    viewModel.clearConversation()
                } label: {
                    Label("Effacer", systemImage: "trash")
                }
                .help("Effacer la conversation")
                .disabled(viewModel.currentMessages.isEmpty)
            }
        }
    }

    // MARK: - Zone des messages

    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.currentMessages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    // Bulle de streaming en cours d'affichage
                    if viewModel.isStreaming {
                        if viewModel.streamingBuffer.isEmpty {
                            TypingIndicator()
                                .id("typing-indicator")
                        } else {
                            StreamingBubble(text: viewModel.streamingBuffer)
                                .id("streaming-bubble")
                        }
                    }

                    // Ancre invisible pour le scroll automatique
                    Color.clear
                        .frame(height: 1)
                        .id("bottom-anchor")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            // Scroll automatique lors de nouveaux messages
            .onChange(of: viewModel.currentMessages.count) {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom-anchor", anchor: .bottom)
                }
            }
            // Scroll automatique pendant le streaming
            .onChange(of: viewModel.streamingBuffer) {
                proxy.scrollTo("bottom-anchor", anchor: .bottom)
            }
        }
    }

    // MARK: - Zone de saisie

    private var inputArea: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Votre message…", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.background)
                        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                )
                .disabled(viewModel.isStreaming)
                // Envoi par Entrée (sans Shift)
                .onKeyPress(.return) {
                    guard !viewModel.isStreaming else { return .ignored }
                    Task { await viewModel.sendMessage() }
                    return .handled
                }

            // Bouton stream (prioritaire — montre le streaming en temps réel)
            Button {
                Task { await viewModel.streamMessage() }
            } label: {
                Image(systemName: "bolt.fill")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .disabled(!viewModel.isConfigured || viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isStreaming)
            .help("Envoyer avec streaming")

            // Bouton send classique
            Button {
                Task { await viewModel.sendMessage() }
            } label: {
                Image(systemName: "paperplane.fill")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.isConfigured || viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isStreaming)
            .help("Envoyer (sans streaming)")
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        // Affichage des erreurs sous la zone de saisie
        .overlay(alignment: .top) {
            if let errorMessage = viewModel.errorMessage {
                ErrorBannerView(message: errorMessage) {
                    viewModel.errorMessage = nil
                }
                .offset(y: -40)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(duration: 0.3), value: viewModel.errorMessage)
            }
        }
    }
}

// MARK: - Bulle de streaming

private struct StreamingBubble: View {
    let text: String

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.windowBackgroundColor))
                            .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                    )

                // Indicateur que la réponse est en cours
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                    Text("En cours…")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 4)
            }

            Spacer(minLength: 60)
        }
    }
}

// MARK: - Bannière d'erreur

private struct ErrorBannerView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }
}
