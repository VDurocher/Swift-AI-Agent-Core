import XCTest
import SwiftData
@testable import SwiftAIAgentCore

@available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
final class HistoryManagerTests: XCTestCase {

    // MARK: - Helpers

    /// Crée un HistoryManager avec un ModelContainer en mémoire uniquement (isolé par test)
    private func makeHistoryManager() async throws -> (HistoryManager, ModelContainer) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ConversationRecord.self, MessageRecord.self,
            configurations: config
        )
        let manager = HistoryManager(modelContainer: container)
        return (manager, container)
    }

    // MARK: - Tests

    /// Vérifie que saveConversation persiste bien les messages dans le container
    func testSaveConversation() async throws {
        let (manager, _) = try await makeHistoryManager()

        let messages: [AIMessage] = [
            .user("Bonjour"),
            .assistant("Bonjour, comment puis-je vous aider ?")
        ]
        let response = AIMessage.assistant("Je suis là pour vous aider.")

        try await manager.saveConversation(
            messages: messages,
            response: response,
            modelName: "gpt-4o"
        )

        let conversations = try await manager.loadConversations()
        XCTAssertEqual(conversations.count, 1)
        // 2 messages envoyés + 1 réponse = 3 messages persistés
        XCTAssertEqual(conversations[0].messages.count, 3)
        XCTAssertEqual(conversations[0].model, "gpt-4o")
    }

    /// Vérifie que loadConversations retourne les conversations par ordre décroissant
    func testLoadConversationsOrder() async throws {
        let (manager, _) = try await makeHistoryManager()

        // Première conversation
        try await manager.saveConversation(
            messages: [.user("Premier message")],
            response: .assistant("Première réponse"),
            modelName: "gpt-4o"
        )

        // Petite pause pour garantir des timestamps distincts
        try await Task.sleep(nanoseconds: 10_000_000)

        // Deuxième conversation (plus récente)
        try await manager.saveConversation(
            messages: [.user("Deuxième message")],
            response: .assistant("Deuxième réponse"),
            modelName: "claude-sonnet-4-6"
        )

        let conversations = try await manager.loadConversations()
        XCTAssertEqual(conversations.count, 2)
        // La plus récente doit être en premier (ordre décroissant)
        XCTAssertEqual(conversations[0].model, "claude-sonnet-4-6")
        XCTAssertEqual(conversations[1].model, "gpt-4o")
    }

    /// Vérifie que loadPreviousContext respecte la limite de messages
    func testLoadPreviousContextLimit() async throws {
        let (manager, _) = try await makeHistoryManager()

        // Crée 5 messages utilisateur + 1 réponse = 6 messages au total
        let messages: [AIMessage] = (1...5).map { .user("Message \($0)") }
        let response = AIMessage.assistant("Réponse finale")

        try await manager.saveConversation(
            messages: messages,
            response: response,
            modelName: "gpt-4o"
        )

        // Limite à 3 messages
        let context = try await manager.loadPreviousContext(limit: 3)
        XCTAssertEqual(context.count, 3)
    }

    /// Vérifie que deleteConversation supprime correctement la conversation ciblée
    func testDeleteConversation() async throws {
        let (manager, _) = try await makeHistoryManager()

        try await manager.saveConversation(
            messages: [.user("À supprimer")],
            response: .assistant("Réponse"),
            modelName: "gpt-4o"
        )

        let conversations = try await manager.loadConversations()
        XCTAssertEqual(conversations.count, 1)

        let targetID = conversations[0].id
        try await manager.deleteConversation(id: targetID)

        let remaining = try await manager.loadConversations()
        XCTAssertEqual(remaining.count, 0)
    }

    /// Vérifie que le prompt système est bien persisté avec la conversation
    func testSaveConversationWithSystemPrompt() async throws {
        let (manager, _) = try await makeHistoryManager()

        let messages: [AIMessage] = [
            .system("Tu es un assistant expert en Swift."),
            .user("Comment fonctionne async/await ?")
        ]
        let response = AIMessage.assistant("async/await est un mécanisme de concurrence...")

        try await manager.saveConversation(
            messages: messages,
            response: response,
            modelName: "claude-35-sonnet"
        )

        let conversations = try await manager.loadConversations()
        XCTAssertEqual(conversations.count, 1)
        XCTAssertEqual(conversations[0].systemPrompt, "Tu es un assistant expert en Swift.")
    }

    /// Vérifie que conversationToMessages convertit correctement les records en AIMessage
    func testConversationToMessages() async throws {
        let (manager, _) = try await makeHistoryManager()

        let originalMessages: [AIMessage] = [
            .user("Question"),
            .assistant("Réponse intermédiaire")
        ]
        let response = AIMessage.assistant("Réponse finale")

        try await manager.saveConversation(
            messages: originalMessages,
            response: response,
            modelName: "gpt-4o"
        )

        let conversations = try await manager.loadConversations()
        XCTAssertEqual(conversations.count, 1)

        let converted = await manager.conversationToMessages(conversations[0])

        // Vérifie le nombre total de messages convertis
        XCTAssertEqual(converted.count, 3)

        // Vérifie que les rôles sont correctement restaurés
        XCTAssertEqual(converted[0].role, .user)
        XCTAssertEqual(converted[1].role, .assistant)
        XCTAssertEqual(converted[2].role, .assistant)

        // Vérifie le contenu des messages
        XCTAssertEqual(converted[0].content, "Question")
        XCTAssertEqual(converted[2].content, "Réponse finale")
    }
}
