import Foundation

/// Base network client with retry logic
actor NetworkClient: Sendable {
    private let session: URLSession
    private let retryPolicy: RetryPolicy

    init(
        session: URLSession = .shared,
        retryPolicy: RetryPolicy = .default
    ) {
        self.session = session
        self.retryPolicy = retryPolicy
    }

    /// Execute a request with automatic retry on failure
    func execute(
        request: URLRequest,
        attempt: Int = 0
    ) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIError.invalidResponse(statusCode: 0, message: "Invalid response type")
            }

            // Handle rate limiting
            if httpResponse.statusCode == 429 {
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                    .flatMap(Double.init)
                throw AIError.rateLimit(retryAfter: retryAfter)
            }

            // Handle errors — truncate body to avoid leaking sensitive provider info
            if !(200...299).contains(httpResponse.statusCode) {
                let raw = String(data: data, encoding: .utf8)
                let message = raw.map { String($0.prefix(Self.maxErrorMessageLength)) }
                throw AIError.invalidResponse(statusCode: httpResponse.statusCode, message: message)
            }

            return (data, httpResponse)

        } catch let error as AIError where error.isRecoverable && attempt < retryPolicy.maxRetries {
            // Retry on recoverable errors
            let delay = retryPolicy.delay(for: attempt)
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            return try await execute(request: request, attempt: attempt + 1)

        } catch {
            throw error
        }
    }

    /// Maximum size of a single SSE message buffer (1 MB) — guards against unbounded memory growth
    private static let maxSSEBufferSize = 1 * 1024 * 1024

    /// Maximum length of an HTTP error body exposed in AIError (prevents leaking large server responses)
    private static let maxErrorMessageLength = 500

    /// Stream response using Server-Sent Events (SSE)
    func stream(
        request: URLRequest
    ) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode) else {
                        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                        throw AIError.invalidResponse(statusCode: statusCode, message: nil)
                    }

                    var buffer = Data()

                    for try await byte in bytes {
                        buffer.append(byte)

                        // Guard against unbounded memory growth from a malformed SSE stream
                        if buffer.count > Self.maxSSEBufferSize {
                            throw AIError.streamingError("SSE message exceeded the 1 MB buffer limit")
                        }

                        // Check for SSE message delimiter (\n\n)
                        if buffer.suffix(2) == Data([0x0A, 0x0A]) {
                            continuation.yield(buffer)
                            buffer.removeAll(keepingCapacity: true)
                        }
                    }

                    // Yield any remaining data
                    if !buffer.isEmpty {
                        continuation.yield(buffer)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
