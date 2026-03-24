import Foundation
import SwiftAIAgentCore

// Représente une session de conversation identifiée
struct ChatSession: Identifiable, Sendable {
    let id: UUID
    var title: String
    var messages: [AIMessage]
    let createdAt: Date

    init(title: String = "Nouveau chat") {
        self.id = UUID()
        self.title = title
        self.messages = []
        self.createdAt = Date()
    }
}
