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
    private var lastEventId: String?
    // nonisolated: JSONEncoder/JSONDecoder are thread-safe for encoding/decoding. Isolated to instance lifetime.
    nonisolated private let jsonEncoder = JSONEncoder()
    nonisolated private let jsonDecoder = JSONDecoder()

    init(baseURL: String = "http://localhost:9999") {
        self.baseURL = baseURL

        // Configure custom URLSession with longer timeouts for SSE streaming
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300  // 5 minutes for initial response
        config.timeoutIntervalForResource = 3600 // 1 hour for entire stream duration
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = false // Disable SSE in Low Data Mode
        self.session = URLSession(configuration: config)
    }

    deinit {
        streamTask?.cancel()
        session.invalidateAndCancel()
    }

    /// Start streaming a chat request
    func startStream(request: ChatStreamRequest) {
        // Cancel any existing stream before starting a new one
        if isStreaming {
            AppLogger.shared.info("Cancelling previous stream before starting new one", category: "sse")
            cancel()
        }

        isStreaming = true
        messages = []
        error = nil
        currentRequest = request
        reconnectAttempts = 0
        connectionState = .connecting

        streamTask = Task { [weak self] in
            await self?.performStream(request: request)
        }
    }

    private func performStream(request: ChatStreamRequest) async {
        let url = URL(string: "\(baseURL)/api/v1/chat/stream")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue("text/event-stream", forHTTPHeaderField: "Accept")

        if let lastEventId {
            urlRequest.addValue(lastEventId, forHTTPHeaderField: "Last-Event-ID")
        }

        do {
            urlRequest.httpBody = try jsonEncoder.encode(request)
        } catch {
            AppLogger.shared.error("Encode error: \(error)", category: "sse")
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

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw APIError.invalidResponse
            }

            connectionState = .connected
            reconnectAttempts = 0

            // Track last received data or heartbeat for stale connection detection
            let lastActivity = LastActivityTracker()

            // Watchdog: detect stale connections (no data/heartbeat in 45s)
            let heartbeatWatchdog = Task.detached { [weak self] in
                while !Task.isCancelled {
                    try await Task.sleep(nanoseconds: 15_000_000_000) // Check every 15s
                    if await lastActivity.secondsSinceLastActivity() > 45 {
                        AppLogger.shared.warning("SSE heartbeat timeout — no activity in 45s", category: "sse")
                        throw URLError(.timedOut)
                    }
                    // Verify self still exists
                    guard self != nil else { return }
                }
            }
            defer { heartbeatWatchdog.cancel() }

            var currentEvent = ""
            var currentData = ""

            for try await line in asyncBytes.lines {
                await lastActivity.touch() // Reset on ANY received line

                if line.hasPrefix("event:") {
                    currentEvent = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("id:") {
                    lastEventId = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("data:") {
                    currentData = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)

                    if !currentData.isEmpty {
                        await parseAndAddMessage(event: currentEvent, data: currentData)
                    }

                    currentEvent = ""
                    currentData = ""
                } else if line.hasPrefix(":") {
                    // Heartbeat/ping comment — activity already tracked above
                    continue
                }
            }

            // Stream completed normally
            AppLogger.shared.info("Stream completed normally", category: "sse")
            connectionState = .disconnected
        } catch is CancellationError {
            AppLogger.shared.info("Stream cancelled", category: "sse")
            connectionState = .disconnected
        } catch {
            AppLogger.shared.error("Stream error: \(error)", category: "sse")
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

        AppLogger.shared.warning("Reconnection attempt \(reconnectAttempts)/\(maxReconnectAttempts)", category: "sse")

        // Exponential backoff capped at 30 seconds
        let delay = min(reconnectDelay * UInt64(1 << (reconnectAttempts - 1)), 30_000_000_000)
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
        // Handle special event types
        switch event {
        case "done":
            AppLogger.shared.info("Received done event — stream complete", category: "sse")
            return
        case "messageId":
            parseMessageIdEvent(data: data)
            return
        default:
            break
        }

        guard let jsonData = data.data(using: .utf8) else {
            AppLogger.shared.error("Failed to convert data to UTF8", category: "sse")
            return
        }

        do {
            let message = try jsonDecoder.decode(StreamMessage.self, from: jsonData)
            messages.append(message)
        } catch {
            AppLogger.shared.error("Decode error: \(error)", category: "sse")
            AppLogger.shared.error("Raw data: \(data)", category: "sse")
        }
    }

    /// Codable struct for SSE messageId event data.
    private struct MessageIdEvent: Decodable {
        let userMessageId: String?
        let assistantMessageId: String?
    }

    private func parseMessageIdEvent(data: String) {
        guard let jsonData = data.data(using: .utf8) else {
            return
        }
        do {
            let event = try jsonDecoder.decode(MessageIdEvent.self, from: jsonData)
            userMessageId = event.userMessageId
            assistantMessageId = event.assistantMessageId
        } catch {
            AppLogger.shared.error("Failed to decode messageId event: \(error)", category: "sse")
        }
    }

    /// Cancel the current stream
    func cancel() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        connectionState = .disconnected
        currentRequest = nil
        reconnectAttempts = 0
        lastEventId = nil
        userMessageId = nil
        assistantMessageId = nil
    }
}

/// Thread-safe tracker for last SSE activity timestamp
private actor LastActivityTracker {
    private var lastActivity = Date()

    func touch() {
        lastActivity = Date()
    }

    func secondsSinceLastActivity() -> TimeInterval {
        Date().timeIntervalSince(lastActivity)
    }
}
