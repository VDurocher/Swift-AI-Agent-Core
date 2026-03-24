import Foundation
import SwiftUI
import os
import SwiftAIAgentCore

// Logger dédié au ViewModel principal
private let logger = Logger(subsystem: "com.portfolio.chatapp", category: "ChatViewModel")

/// ViewModel principal gérant l'état du chat et les appels à l'agent IA.
/// Utilise @Observable (Swift 5.9+) et @MainActor pour la sécurité de concurrence.
@Observable @MainActor final class ChatViewModel {

    // MARK: - État observable

    var sessions: [ChatSession] = [ChatSession()]
    var selectedSessionID: UUID?
    var inputText: String = ""
    var isStreaming: Bool = false
    var errorMessage: String? = nil
    /// Texte en cours d'accumulation pendant le streaming
    var streamingBuffer: String = ""

    // MARK: - Configuration

    var selectedProvider: AIProvider = .anthropic
    var apiKey: String = ""
    var selectedModel: AIModel = .claudeSonnet46

    // MARK: - Dépendances privées

    private var agent: (any AIAgent)?

    // MARK: - Propriétés calculées

    var isConfigured: Bool { agent != nil }

    var currentSession: ChatSession? {
        guard let id = selectedSessionID else { return sessions.first }
        return sessions.first { $0.id == id }
    }

    var currentMessages: [AIMessage] {
        currentSession?.messages ?? []
    }

    /// Modèles disponibles filtrés selon le provider sélectionné
    var availableModels: [AIModel] {
        switch selectedProvider {
        case .openai:
            return [.gpt4o, .gpt4oMini, .gpt4Turbo, .gpt4, .gpt35Turbo]
        case .anthropic:
            return [.claudeSonnet46, .claude35Sonnet, .claude35Haiku, .claude3Opus, .claude3Haiku]
        }
    }

    // MARK: - Initialisation

    init() {
        // Sélectionne automatiquement la première session au démarrage
        selectedSessionID = sessions.first?.id
    }

    // MARK: - Configuration de l'agent

    /// Crée et configure l'agent IA selon les paramètres courants
    func configure() {
        errorMessage = nil
        do {
            let configuration = AIConfiguration(model: selectedModel, apiKey: apiKey)
            agent = try AIAgentImplementation(configuration: configuration)
            logger.info("Agent configuré avec le modèle \(selectedModel.name)")
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Échec de configuration de l'agent : \(error.localizedDescription)")
        }
    }

    // MARK: - Gestion des sessions

    /// Crée une nouvelle session et la sélectionne
    func createNewSession() {
        let session = ChatSession()
        sessions.insert(session, at: 0)
        selectedSessionID = session.id
    }

    /// Sélectionne une session existante par son identifiant
    func selectSession(_ session: ChatSession) {
        selectedSessionID = session.id
    }

    // MARK: - Envoi de messages

    /// Envoie le message saisi via un appel classique (non-streaming)
    func sendMessage() async {
        guard canSend() else { return }

        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""
        errorMessage = nil

        let userMessage = AIMessage.user(text)
        appendToCurrentSession(userMessage)

        isStreaming = true
        defer { isStreaming = false }

        do {
            guard let agent else { return }
            let allMessages = currentMessages
            let response = try await agent.send(messages: allMessages)
            appendToCurrentSession(response)
            updateSessionTitle(from: text)
            logger.debug("Réponse reçue : \(response.content.prefix(50))")
        } catch {
            handleAgentError(error)
        }
    }

    /// Envoie le message saisi avec streaming en temps réel
    func streamMessage() async {
        guard canSend() else { return }

        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""
        errorMessage = nil
        streamingBuffer = ""

        let userMessage = AIMessage.user(text)
        appendToCurrentSession(userMessage)

        isStreaming = true
        defer {
            isStreaming = false
            streamingBuffer = ""
        }

        do {
            guard let agent else { return }
            let allMessages = currentMessages

            for try await chunk in agent.stream(messages: allMessages) {
                streamingBuffer += chunk
            }

            // Finalise le message une fois le stream terminé
            let assistantMessage = AIMessage.assistant(streamingBuffer)
            appendToCurrentSession(assistantMessage)
            updateSessionTitle(from: text)
            logger.debug("Stream terminé — \(self.streamingBuffer.count) caractères reçus")
        } catch {
            handleAgentError(error)
        }
    }

    /// Efface tous les messages de la session courante
    func clearConversation() {
        guard let index = currentSessionIndex() else { return }
        sessions[index].messages = []
        logger.info("Conversation effacée pour la session \(sessions[index].id)")
    }

    // MARK: - Helpers privés

    private func canSend() -> Bool {
        guard isConfigured else {
            errorMessage = "L'agent n'est pas configuré. Veuillez entrer votre clé API."
            return false
        }
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !isStreaming
    }

    private func appendToCurrentSession(_ message: AIMessage) {
        guard let index = currentSessionIndex() else { return }
        sessions[index].messages.append(message)
    }

    private func currentSessionIndex() -> Int? {
        guard let id = selectedSessionID ?? sessions.first?.id else { return nil }
        return sessions.firstIndex { $0.id == id }
    }

    /// Met à jour le titre de la session avec les premiers mots du message utilisateur
    private func updateSessionTitle(from userText: String) {
        guard let index = currentSessionIndex() else { return }
        let title = String(userText.prefix(40))
        if sessions[index].title == "Nouveau chat" {
            sessions[index].title = title.isEmpty ? "Nouveau chat" : title
        }
    }

    private func handleAgentError(_ error: Error) {
        if let aiError = error as? AIError {
            errorMessage = aiError.errorDescription ?? error.localizedDescription
            logger.error("Erreur AIAgent : \(aiError.localizedDescription)")
        } else {
            errorMessage = error.localizedDescription
            logger.error("Erreur inattendue : \(error.localizedDescription)")
        }
    }
}
