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

    private var streamTask: Task<Void, Never>?
    private let baseURL: String
    private var currentRequest: ChatStreamRequest?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 3
    private let reconnectDelay: UInt64 = 2_000_000_000 // 2 seconds in nanoseconds
    private let session: URLSession
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()

    init(baseURL: String = "http://localhost:9090") {
        self.baseURL = baseURL

        // Configure custom URLSession with longer timeouts for SSE streaming
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300  // 5 minutes for initial response
        config.timeoutIntervalForResource = 3600 // 1 hour for entire stream duration
        self.session = URLSession(configuration: config)
    }

    /// Start streaming a chat request
    func startStream(request: ChatStreamRequest) {
        // Cancel any existing stream before starting a new one
        if isStreaming {
            print("[SSEClient] Cancelling previous stream before starting new one")
            cancel()
        }

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
        print("[SSEClient] Request URL: \(url)")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue("text/event-stream", forHTTPHeaderField: "Accept")

        do {
            urlRequest.httpBody = try jsonEncoder.encode(request)
        } catch {
            print("[SSEClient] Encode error: \(error)")
            self.error = error
            self.isStreaming = false
            return
        }

        do {
            // Race connection against 60s timeout
            let (asyncBytes, response) = try await withThrowingTaskGroup(of: (URLSession.AsyncBytes, URLResponse).self) { group in
                // Connection task
                group.addTask {
                    try await self.session.bytes(for: urlRequest)
                }

                // Timeout task
                group.addTask {
                    try await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
                    throw URLError(.timedOut)
                }

                // Return first to complete, cancel the other
                let result = try await group.next()!
                group.cancelAll()
                return result
            }

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("[SSEClient] Response status: \(statusCode)")

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw APIError.invalidResponse
            }

            connectionState = .connected
            reconnectAttempts = 0

            var currentEvent = ""
            var currentData = ""

            for try await line in asyncBytes.lines {
                print("[SSEClient] Line: \(line.prefix(120))")
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
            print("[SSEClient] Stream completed normally")
            connectionState = .disconnected
        } catch is CancellationError {
            print("[SSEClient] Stream cancelled")
            connectionState = .disconnected
        } catch {
            print("[SSEClient] Stream error: \(error)")
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

    /// Message IDs sent by server for client correlation
    @Published var userMessageId: String?
    @Published var assistantMessageId: String?

    private func parseAndAddMessage(event: String, data: String) async {
        print("[SSEClient] Parsing event=\(event) data=\(data.prefix(120))")

        // Handle special event types
        switch event {
        case "done":
            print("[SSEClient] Received done event — stream complete")
            return
        case "messageId":
            parseMessageIdEvent(data: data)
            return
        default:
            break
        }

        guard let jsonData = data.data(using: .utf8) else {
            print("[SSEClient] Failed to convert data to UTF8")
            return
        }

        do {
            let message = try jsonDecoder.decode(StreamMessage.self, from: jsonData)
            messages.append(message)
            print("[SSEClient] Parsed message successfully, total messages: \(messages.count)")
        } catch {
            print("[SSEClient] DECODE ERROR: \(error)")
            print("[SSEClient] Raw data: \(data)")
        }
    }

    private func parseMessageIdEvent(data: String) {
        guard let jsonData = data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String] else {
            return
        }
        userMessageId = json["userMessageId"]
        assistantMessageId = json["assistantMessageId"]
        print("[SSEClient] Message IDs: user=\(userMessageId ?? "nil"), assistant=\(assistantMessageId ?? "nil")")
    }

    /// Cancel the current stream
    func cancel() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        connectionState = .disconnected
        currentRequest = nil
        reconnectAttempts = 0
        userMessageId = nil
        assistantMessageId = nil
    }
}
