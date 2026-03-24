import Foundation

/// Anthropic (Claude) API client implementation
actor AnthropicClient: Sendable {
    private let networkClient: NetworkClient
    private let configuration: AIConfiguration

    init(configuration: AIConfiguration) {
        self.configuration = configuration
        self.networkClient = NetworkClient(retryPolicy: configuration.retryPolicy)
    }

    // MARK: - Request/Response Models

    private struct MessagesRequest: Encodable {
        let model: String
        let messages: [Message]
        let maxTokens: Int
        let temperature: Double
        let system: String?
        let stream: Bool
        /// Outils disponibles au format Anthropic (optionnel)
        let tools: [ToolDefinition]?

        enum CodingKeys: String, CodingKey {
            case model, messages, temperature, system, stream, tools
            case maxTokens = "max_tokens"
        }

        struct Message: Encodable {
            let role: String
            /// Contenu du message — texte ou blocs tool_result selon le rôle
            let content: MessageContent

            /// Encodage polymorphique : texte simple ou tableau de blocs
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: MessageCodingKeys.self)
                try container.encode(role, forKey: .role)
                switch content {
                case .text(let text):
                    try container.encode(text, forKey: .content)
                case .toolResults(let blocks):
                    try container.encode(blocks, forKey: .content)
                }
            }

            enum MessageCodingKeys: String, CodingKey {
                case role, content
            }
        }

        /// Contenu d'un message : texte pur ou blocs de résultats d'outils
        enum MessageContent {
            case text(String)
            case toolResults([ToolResultBlock])
        }

        /// Bloc de résultat d'outil au format Anthropic
        struct ToolResultBlock: Encodable {
            /// Toujours "tool_result" pour le format Anthropic
            let type: String
            let toolUseId: String
            let content: String

            enum CodingKeys: String, CodingKey {
                case type, content
                case toolUseId = "tool_use_id"
            }

            init(toolUseId: String, content: String) {
                self.type = "tool_result"
                self.toolUseId = toolUseId
                self.content = content
            }
        }

        /// Définition d'un outil au format Anthropic
        struct ToolDefinition: Encodable {
            let name: String
            let description: String
            /// Schéma des paramètres au format JSON Schema (clé: "input_schema")
            let inputSchema: AITool.AIToolParameters

            enum CodingKeys: String, CodingKey {
                case name, description
                case inputSchema = "input_schema"
            }
        }
    }

    private struct MessagesResponse: Decodable {
        let id: String
        let content: [Content]
        let stopReason: String?

        enum CodingKeys: String, CodingKey {
            case id, content
            case stopReason = "stop_reason"
        }

        /// Bloc de contenu — peut être un texte ou un appel d'outil
        struct Content: Decodable {
            let type: String
            let text: String?
            /// Identifiant de l'appel d'outil (type "tool_use")
            let id: String?
            /// Nom de l'outil à appeler (type "tool_use")
            let name: String?
            /// Arguments de l'outil sous forme de dictionnaire brut
            let input: AnthropicInput?
        }

        /// Représentation intermédiaire pour les arguments d'outil (JSON dynamique)
        struct AnthropicInput: Decodable {
            let raw: [String: AnthropicValue]

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                raw = try container.decode([String: AnthropicValue].self)
            }

            /// Sérialise les arguments en JSON String pour AIToolCall
            func toJSONString() -> String {
                let dict = raw.mapValues { $0.toAny() }
                guard let data = try? JSONSerialization.data(withJSONObject: dict),
                      let string = String(data: data, encoding: .utf8) else {
                    return "{}"
                }
                return string
            }
        }

        /// Valeur JSON générique pour désérialiser les inputs d'outils Anthropic
        enum AnthropicValue: Decodable {
            case string(String)
            case int(Int)
            case double(Double)
            case bool(Bool)
            case null

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let value = try? container.decode(String.self) {
                    self = .string(value)
                } else if let value = try? container.decode(Int.self) {
                    self = .int(value)
                } else if let value = try? container.decode(Double.self) {
                    self = .double(value)
                } else if let value = try? container.decode(Bool.self) {
                    self = .bool(value)
                } else {
                    self = .null
                }
            }

            func toAny() -> Any {
                switch self {
                case .string(let value): return value
                case .int(let value): return value
                case .double(let value): return value
                case .bool(let value): return value
                case .null: return NSNull()
                }
            }
        }
    }

    private struct StreamEvent: Decodable {
        let type: String
        let delta: Delta?
        let contentBlock: ContentBlock?

        enum CodingKeys: String, CodingKey {
            case type, delta
            case contentBlock = "content_block"
        }

        struct Delta: Decodable {
            let text: String?
        }

        struct ContentBlock: Decodable {
            let text: String?
        }
    }

    // MARK: - Public Methods

    func sendCompletion(messages: [AIMessage]) async throws -> AIMessage {
        let request = try createRequest(messages: messages, tools: nil, stream: false)
        let (data, _) = try await networkClient.execute(request: request)

        let response = try JSONDecoder().decode(MessagesResponse.self, from: data)

        // Extrait le premier bloc texte disponible
        guard let textContent = response.content.first(where: { $0.type == "text" })?.text else {
            throw AIError.invalidResponse(statusCode: 200, message: "No content in response")
        }

        return AIMessage(role: .assistant, content: textContent)
    }

    /// Envoie des messages avec des outils disponibles — le modèle peut retourner des appels d'outils
    func sendCompletionWithTools(messages: [AIMessage], tools: [AITool]) async throws -> AIMessageWithTools {
        let request = try createRequest(messages: messages, tools: tools, stream: false)
        let (data, _) = try await networkClient.execute(request: request)

        let response = try JSONDecoder().decode(MessagesResponse.self, from: data)

        // Extrait le contenu textuel (peut être absent si le modèle n'appelle que des outils)
        let textContent = response.content.first(where: { $0.type == "text" })?.text ?? ""

        // Extrait les appels d'outils des blocs "tool_use"
        let toolCalls: [AIToolCall] = response.content.compactMap { block in
            guard block.type == "tool_use",
                  let callId = block.id,
                  let toolName = block.name else { return nil }
            let arguments = block.input?.toJSONString() ?? "{}"
            return AIToolCall(id: callId, name: toolName, arguments: arguments)
        }

        let assistantMessage = AIMessage(role: .assistant, content: textContent)
        return AIMessageWithTools(message: assistantMessage, toolCalls: toolCalls)
    }

    func streamCompletion(messages: [AIMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = try createRequest(messages: messages, tools: nil, stream: true)
                    let stream = networkClient.stream(request: request)

                    for try await data in stream {
                        let lines = String(data: data, encoding: .utf8)?
                            .components(separatedBy: "\n")
                            .filter { !$0.isEmpty } ?? []

                        for line in lines {
                            guard line.hasPrefix("data: ") else { continue }
                            let jsonString = String(line.dropFirst(6))

                            if let data = jsonString.data(using: .utf8),
                               let event = try? JSONDecoder().decode(StreamEvent.self, from: data) {

                                // Traite les différents types d'événements du stream Anthropic
                                switch event.type {
                                case "content_block_delta":
                                    if let text = event.delta?.text {
                                        continuation.yield(text)
                                    }
                                case "message_stop":
                                    continuation.finish()
                                    return
                                default:
                                    break
                                }
                            }
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func createRequest(messages: [AIMessage], tools: [AITool]?, stream: Bool) throws -> URLRequest {
        try configuration.validate()

        let url = URL(string: "\(configuration.model.provider.baseURL)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = configuration.timeout

        // Extrait le message système (géré séparément par l'API Anthropic)
        let systemMessage = messages.first(where: { $0.role == .system })?.content
        let conversationMessages = messages.filter { $0.role != .system }

        // Convertit les messages en format Anthropic, en gérant les tool results
        let anthropicMessages = conversationMessages.map { message -> MessagesRequest.Message in
            if message.role == .tool, let toolCallId = message.metadata?["tool_call_id"] {
                // Les résultats d'outils utilisent un contenu structuré en blocs
                let block = MessagesRequest.ToolResultBlock(
                    toolUseId: toolCallId,
                    content: message.content
                )
                return MessagesRequest.Message(
                    role: "user",
                    content: .toolResults([block])
                )
            }
            return MessagesRequest.Message(
                role: message.role.anthropicName,
                content: .text(message.content)
            )
        }

        // Convertit les AITool en ToolDefinition Anthropic si présents
        let toolDefinitions = tools.map { toolArray in
            toolArray.map { tool in
                MessagesRequest.ToolDefinition(
                    name: tool.name,
                    description: tool.description,
                    inputSchema: tool.parameters
                )
            }
        }

        let requestBody = MessagesRequest(
            model: configuration.model.name,
            messages: anthropicMessages,
            maxTokens: configuration.maxResponseTokens,
            temperature: configuration.temperature,
            system: systemMessage,
            stream: stream,
            tools: toolDefinitions
        )

        request.httpBody = try JSONEncoder().encode(requestBody)
        return request
    }
}
