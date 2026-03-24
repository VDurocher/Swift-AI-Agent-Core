import Foundation

/// OpenAI API client implementation
actor OpenAIClient: Sendable {
    private let networkClient: NetworkClient
    private let configuration: AIConfiguration

    init(configuration: AIConfiguration) {
        self.configuration = configuration
        self.networkClient = NetworkClient(retryPolicy: configuration.retryPolicy)
    }

    // MARK: - Request/Response Models

    private struct ChatCompletionRequest: Encodable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let maxTokens: Int
        let stream: Bool
        /// Outils disponibles pour le function calling (optionnel)
        let tools: [ToolDefinition]?

        enum CodingKeys: String, CodingKey {
            case model, messages, temperature, tools
            case maxTokens = "max_tokens"
            case stream
        }

        struct Message: Encodable {
            let role: String
            let content: String
            /// Identifiant de l'appel d'outil auquel ce message répond (role "tool" uniquement)
            let toolCallId: String?

            enum CodingKeys: String, CodingKey {
                case role, content
                case toolCallId = "tool_call_id"
            }

            init(role: String, content: String, toolCallId: String? = nil) {
                self.role = role
                self.content = content
                self.toolCallId = toolCallId
            }
        }

        /// Définition d'un outil au format OpenAI function calling
        struct ToolDefinition: Encodable {
            /// Toujours "function" pour le format OpenAI
            let type: String
            let function: FunctionDefinition

            struct FunctionDefinition: Encodable {
                let name: String
                let description: String
                let parameters: AITool.AIToolParameters
            }
        }
    }

    private struct ChatCompletionResponse: Decodable {
        let id: String
        let choices: [Choice]

        struct Choice: Decodable {
            let message: Message
            let finishReason: String?

            enum CodingKeys: String, CodingKey {
                case message
                case finishReason = "finish_reason"
            }
        }

        struct Message: Decodable {
            let role: String
            /// Contenu textuel — peut être nil si le modèle n'appelle que des outils
            let content: String?
            /// Appels d'outils demandés par le modèle (nil si réponse textuelle)
            let toolCalls: [ToolCallResponse]?

            enum CodingKeys: String, CodingKey {
                case role, content
                case toolCalls = "tool_calls"
            }
        }

        /// Appel d'outil tel que retourné par l'API OpenAI
        struct ToolCallResponse: Decodable {
            let id: String
            let function: FunctionCall

            struct FunctionCall: Decodable {
                let name: String
                let arguments: String
            }
        }
    }

    private struct StreamChunk: Decodable {
        let choices: [Choice]

        struct Choice: Decodable {
            let delta: Delta
            let finishReason: String?

            enum CodingKeys: String, CodingKey {
                case delta
                case finishReason = "finish_reason"
            }
        }

        struct Delta: Decodable {
            let content: String?
        }
    }

    // MARK: - Public Methods

    func sendCompletion(messages: [AIMessage]) async throws -> AIMessage {
        let request = try createRequest(messages: messages, tools: nil, stream: false)
        let (data, _) = try await networkClient.execute(request: request)

        let response = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)

        guard let choice = response.choices.first else {
            throw AIError.invalidResponse(statusCode: 200, message: "No choices in response")
        }

        return AIMessage(
            role: AIRole(rawValue: choice.message.role) ?? .assistant,
            content: choice.message.content ?? ""
        )
    }

    /// Envoie des messages avec des outils disponibles — le modèle peut retourner des appels d'outils
    func sendCompletionWithTools(messages: [AIMessage], tools: [AITool]) async throws -> AIMessageWithTools {
        let request = try createRequest(messages: messages, tools: tools, stream: false)
        let (data, _) = try await networkClient.execute(request: request)

        let response = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)

        guard let choice = response.choices.first else {
            throw AIError.invalidResponse(statusCode: 200, message: "No choices in response")
        }

        // Convertit les tool calls de la réponse OpenAI en AIToolCall
        let toolCalls: [AIToolCall] = choice.message.toolCalls?.map { callResponse in
            AIToolCall(
                id: callResponse.id,
                name: callResponse.function.name,
                arguments: callResponse.function.arguments
            )
        } ?? []

        let assistantMessage = AIMessage(
            role: .assistant,
            content: choice.message.content ?? ""
        )

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

                            if jsonString == "[DONE]" {
                                continuation.finish()
                                return
                            }

                            if let data = jsonString.data(using: .utf8),
                               let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data),
                               let content = chunk.choices.first?.delta.content {
                                continuation.yield(content)
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

        let url = URL(string: "\(configuration.model.provider.baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = configuration.timeout

        // Convertit les messages en format OpenAI, en gérant le role "tool" pour les résultats
        let openAIMessages = messages.map { message -> ChatCompletionRequest.Message in
            let toolCallId = message.role == .tool ? message.metadata?["tool_call_id"] : nil
            return ChatCompletionRequest.Message(
                role: message.role.openAIName,
                content: message.content,
                toolCallId: toolCallId
            )
        }

        // Convertit les AITool en ToolDefinition OpenAI si présents
        let toolDefinitions = tools.map { toolArray in
            toolArray.map { tool in
                ChatCompletionRequest.ToolDefinition(
                    type: "function",
                    function: .init(
                        name: tool.name,
                        description: tool.description,
                        parameters: tool.parameters
                    )
                )
            }
        }

        let requestBody = ChatCompletionRequest(
            model: configuration.model.name,
            messages: openAIMessages,
            temperature: configuration.temperature,
            maxTokens: configuration.maxResponseTokens,
            stream: stream,
            tools: toolDefinitions
        )

        request.httpBody = try JSONEncoder().encode(requestBody)
        return request
    }
}
