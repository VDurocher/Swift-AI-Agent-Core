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

        enum CodingKeys: String, CodingKey {
            case model, messages, temperature
            case maxTokens = "max_tokens"
            case stream
        }

        struct Message: Encodable {
            let role: String
            let content: String
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
            let content: String
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
        let request = try createRequest(messages: messages, stream: false)
        let (data, _) = try await networkClient.execute(request: request)

        let response = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)

        guard let choice = response.choices.first else {
            throw AIError.invalidResponse(statusCode: 200, message: "No choices in response")
        }

        return AIMessage(
            role: AIRole(rawValue: choice.message.role) ?? .assistant,
            content: choice.message.content
        )
    }

    func streamCompletion(messages: [AIMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = try createRequest(messages: messages, stream: true)
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

    private func createRequest(messages: [AIMessage], stream: Bool) throws -> URLRequest {
        try configuration.validate()

        let url = URL(string: "\(configuration.model.provider.baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = configuration.timeout

        let requestBody = ChatCompletionRequest(
            model: configuration.model.name,
            messages: messages.map {
                ChatCompletionRequest.Message(role: $0.role.openAIName, content: $0.content)
            },
            temperature: configuration.temperature,
            maxTokens: configuration.maxResponseTokens,
            stream: stream
        )

        request.httpBody = try JSONEncoder().encode(requestBody)
        return request
    }
}
