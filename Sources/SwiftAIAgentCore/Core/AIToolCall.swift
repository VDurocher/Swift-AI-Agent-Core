import Foundation

/// Appel d'outil demandé par le modèle dans une réponse
public struct AIToolCall: Sendable, Codable, Hashable {
    /// Identifiant unique de l'appel (ex: "call_abc123"), nécessaire pour apparier le résultat
    public let id: String
    /// Nom de l'outil à appeler
    public let name: String
    /// Arguments de l'outil encodés en JSON String
    public let arguments: String

    public init(id: String, name: String, arguments: String) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }

    /// Tente de décoder les arguments en dictionnaire clé/valeur
    /// Retourne nil si le JSON est invalide ou ne correspond pas à un objet
    public func decodeArguments() -> [String: Any]? {
        guard let data = arguments.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}

/// Résultat d'un appel d'outil fourni par l'application hôte
public struct AIToolResult: Sendable {
    /// Identifiant de l'appel d'outil correspondant — doit correspondre à AIToolCall.id
    public let toolCallId: String
    /// Résultat de l'exécution sous forme de texte
    public let content: String

    public init(toolCallId: String, content: String) {
        self.toolCallId = toolCallId
        self.content = content
    }
}

/// Réponse de l'agent pouvant contenir du texte et/ou des appels d'outils
public struct AIMessageWithTools: Sendable {
    /// Message texte de l'agent (content peut être vide si le modèle n'appelle que des outils)
    public let message: AIMessage
    /// Appels d'outils demandés par le modèle (vide si réponse textuelle pure)
    public let toolCalls: [AIToolCall]

    /// Indique si l'application doit exécuter des outils avant de continuer la conversation
    public var requiresToolExecution: Bool { !toolCalls.isEmpty }

    public init(message: AIMessage, toolCalls: [AIToolCall] = []) {
        self.message = message
        self.toolCalls = toolCalls
    }
}
