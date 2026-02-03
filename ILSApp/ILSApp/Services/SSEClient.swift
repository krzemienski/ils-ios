import Foundation
import Combine
import ILSShared

/// Server-Sent Events client for streaming chat responses
@MainActor
class SSEClient: ObservableObject {
    @Published var messages: [StreamMessage] = []
    @Published var isStreaming: Bool = false
    @Published var error: Error?
    @Published var connectionState: ConnectionState = .disconnected

    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case reconnecting(attempt: Int)
    }

    private var task: URLSessionDataTask?
    private var streamTask: Task<Void, Never>?
    private let baseURL: String
    private var currentRequest: ChatStreamRequest?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 3
    private let reconnectDelay: UInt64 = 2_000_000_000 // 2 seconds in nanoseconds
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(baseURL: String = "http://localhost:8080") {
        self.baseURL = baseURL

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    /// Start streaming a chat request
    func startStream(request: ChatStreamRequest) {
        guard !isStreaming else { return }

        isStreaming = true
        messages = []
        error = nil
        currentRequest = request
        reconnectAttempts = 0
        connectionState = .connecting

        streamTask = Task {
            await performStream(request: request)
        }
    }

    private func performStream(request: ChatStreamRequest) async {
        let url = URL(string: "\(baseURL)/api/v1/chat/stream")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue("text/event-stream", forHTTPHeaderField: "Accept")

        do {
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            self.error = error
            self.isStreaming = false
            return
        }

        do {
            let (asyncBytes, response) = try await URLSession.shared.bytes(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw APIError.invalidResponse
            }

            connectionState = .connected
            reconnectAttempts = 0

            var currentEvent = ""
            var currentData = ""

            for try await line in asyncBytes.lines {
                if line.hasPrefix("event:") {
                    currentEvent = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("data:") {
                    currentData = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)

                    if !currentData.isEmpty {
                        await parseAndAddMessage(event: currentEvent, data: currentData)
                    }

                    currentEvent = ""
                    currentData = ""
                } else if line.hasPrefix(":") {
                    // Heartbeat/ping comment - ignore
                    continue
                }
            }

            // Stream completed normally
            connectionState = .disconnected
        } catch is CancellationError {
            // Task was cancelled, don't reconnect
            connectionState = .disconnected
        } catch {
            // Network error - attempt reconnection
            if await shouldReconnect(error: error) {
                return
            }
            self.error = error
            connectionState = .disconnected
        }

        isStreaming = false
    }

    /// Determine if we should attempt reconnection
    private func shouldReconnect(error: Error) async -> Bool {
        guard let request = currentRequest,
              reconnectAttempts < maxReconnectAttempts,
              isNetworkError(error) else {
            return false
        }

        reconnectAttempts += 1
        connectionState = .reconnecting(attempt: reconnectAttempts)

        print("SSEClient: Reconnection attempt \(reconnectAttempts)/\(maxReconnectAttempts)")

        // Exponential backoff
        let delay = reconnectDelay * UInt64(reconnectAttempts)
        try? await Task.sleep(nanoseconds: delay)

        // Check if cancelled during sleep
        if Task.isCancelled {
            return false
        }

        // Attempt reconnection
        await performStream(request: request)
        return true
    }

    /// Check if the error is a network-related error that warrants reconnection
    private func isNetworkError(_ error: Error) -> Bool {
        let nsError = error as NSError

        // URLError codes that indicate network issues
        let networkErrorCodes: [Int] = [
            NSURLErrorNetworkConnectionLost,
            NSURLErrorNotConnectedToInternet,
            NSURLErrorTimedOut,
            NSURLErrorCannotConnectToHost,
            NSURLErrorCannotFindHost,
            NSURLErrorDNSLookupFailed
        ]

        return nsError.domain == NSURLErrorDomain && networkErrorCodes.contains(nsError.code)
    }

    private func parseAndAddMessage(event: String, data: String) async {
        guard let jsonData = data.data(using: .utf8) else { return }

        do {
            let message = try decoder.decode(StreamMessage.self, from: jsonData)
            messages.append(message)
        } catch {
            print("Failed to parse SSE message: \(error)")
        }
    }

    /// Cancel the current stream
    func cancel() {
        streamTask?.cancel()
        streamTask = nil
        task?.cancel()
        task = nil
        isStreaming = false
        connectionState = .disconnected
        currentRequest = nil
        reconnectAttempts = 0
    }
}

// MARK: - Chat Request

struct ChatStreamRequest: Encodable {
    let prompt: String
    let sessionId: UUID?
    let projectId: UUID?
    let options: ChatOptions?
}

struct ChatOptions: Encodable {
    let model: String?
    let permissionMode: String?
    let maxTurns: Int?
}
