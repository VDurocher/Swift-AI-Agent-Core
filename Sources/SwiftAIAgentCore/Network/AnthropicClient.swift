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

        enum CodingKeys: String, CodingKey {
            case model, messages, temperature, system, stream
            case maxTokens = "max_tokens"
        }

        struct Message: Encodable {
            let role: String
            let content: String
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

        struct Content: Decodable {
            let type: String
            let text: String
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
        let request = try createRequest(messages: messages, stream: false)
        let (data, _) = try await networkClient.execute(request: request)

        let response = try JSONDecoder().decode(MessagesResponse.self, from: data)

        guard let content = response.content.first?.text else {
            throw AIError.invalidResponse(statusCode: 200, message: "No content in response")
        }

        return AIMessage(role: .assistant, content: content)
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

                            if let data = jsonString.data(using: .utf8),
                               let event = try? JSONDecoder().decode(StreamEvent.self, from: data) {

                                // Handle different event types
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

    private func createRequest(messages: [AIMessage], stream: Bool) throws -> URLRequest {
        try configuration.validate()

        let url = URL(string: "\(configuration.model.provider.baseURL)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = configuration.timeout

        // Extract system message if present
        let systemMessage = messages.first(where: { $0.role == .system })?.content
        let conversationMessages = messages.filter { $0.role != .system }

        let requestBody = MessagesRequest(
            model: configuration.model.name,
            messages: conversationMessages.map {
                MessagesRequest.Message(role: $0.role.anthropicName, content: $0.content)
            },
            maxTokens: configuration.maxResponseTokens,
            temperature: configuration.temperature,
            system: systemMessage,
            stream: stream
        )

        request.httpBody = try JSONEncoder().encode(requestBody)
        return request
    }
}
