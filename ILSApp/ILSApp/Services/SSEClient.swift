// CONC-22 / MOD-007: @preconcurrency suppresses Sendable warnings from URLSession delegate
// conformance and task group patterns. URLSession is @unchecked Sendable but its key paths
// trigger false positives in strict concurrency mode. Scoping to individual types is not
// feasible because the warnings originate from URLSession's own API surface.
@preconcurrency import Foundation
import Observation
import ILSShared
import os
#if os(iOS)
import UIKit
#endif

/// Server-Sent Events client for streaming chat responses
@MainActor
@Observable
class SSEClient {
    var messages: [StreamMessage] = []
    var isStreaming: Bool = false
    var error: Error?
    var connectionState: ConnectionState = .disconnected

    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case reconnecting(attempt: Int)
    }

    // @ObservationIgnored: Internal lifecycle state, not view-observable.
    // Required so deinit (nonisolated) can access them for safety-net cancellation.
    @ObservationIgnored private var streamTask: Task<Void, Never>?
    private let baseURL: String
    private var currentRequest: ChatStreamRequest?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10
    private let reconnectDelay: UInt64 = 2_000_000_000 // 2 seconds in nanoseconds
    private let session: URLSession
    private var lastEventId: String?
    // NET-RES-1: Cancellable handle to the current backoff sleep task so network
    // restoration can skip remaining wait and trigger an immediate retry.
    private var backoffSleepTask: Task<Void, Never>?
    // CONC-001: Generation counter incremented on each connect. Captured by watchdog
    // so a stale watchdog from a previous stream cannot cancel the current one.
    private var streamGeneration: UInt64 = 0
    // NET-RES-1: Observer for network restoration to cancel backoff and reconnect.
    // nonisolated(unsafe): Accessed in deinit (nonisolated) for safety-net cleanup.
    // Only mutated on MainActor; deinit is the sole nonisolated access point.
    @ObservationIgnored nonisolated(unsafe) private var networkObserver: NSObjectProtocol?
    #if os(iOS)
    @ObservationIgnored nonisolated(unsafe) private var backgroundObserver: NSObjectProtocol?
    #endif
    // nonisolated: JSONEncoder/JSONDecoder are thread-safe for encoding/decoding. Isolated to instance lifetime.
    nonisolated private let jsonEncoder = JSONEncoder()
    nonisolated private let jsonDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init(baseURL: String = "http://localhost:9999") {
        self.baseURL = baseURL

        // Configure custom URLSession with longer timeouts for SSE streaming
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300  // 5 minutes for initial response
        config.timeoutIntervalForResource = 3600 // 1 hour for entire stream duration
        // ENRG-003: User-configurable — defaults to true, but respects UserDefaults override.
        config.allowsExpensiveNetworkAccess = UserDefaults.standard.object(forKey: "allowsExpensiveNetworkAccess") as? Bool ?? true
        // ENRG-02: Intentionally false — SSE streaming should not consume metered data in Low Data Mode.
        // Users can still use the app with cached data; streaming resumes when Low Data Mode is disabled.
        config.allowsConstrainedNetworkAccess = false
        // PLAT-04 / NET-003: Respect user preference for cellular data access (defaults to true).
        // Note: URLSessionConfiguration is snapshot-on-init — changes to UserDefaults after
        // SSEClient creation require a new SSEClient instance to take effect.
        config.allowsCellularAccess = UserDefaults.standard.object(forKey: "allowsCellularAccess") as? Bool ?? true
        self.session = URLSession(configuration: config)

        // ENRG-05: Cancel active SSE stream on background to save battery radio.
        // NotificationCenter observer is registered on main queue to match @MainActor isolation.
        #if os(iOS)
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isStreaming else { return }
                self.cancel()
            }
        }
        #endif

        // NET-RES-1: Subscribe to network restoration so any active backoff sleep is
        // cancelled immediately, triggering a faster reconnection attempt.
        networkObserver = NotificationCenter.default.addObserver(
            forName: .networkDidBecomeAvailable,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handleNetworkRestoration()
            }
        }
    }

    /// Safety-net deinit: cancels stream task and removes NotificationCenter observer
    /// if cleanup() was not called from the view lifecycle. Primary cleanup path
    /// remains cleanup() called from view's onDisappear.
    /// Task.cancel() and NotificationCenter.removeObserver() are thread-safe.
    deinit {
        streamTask?.cancel()
        // MEM-002: Remove network observer in deinit as safety net (cleanup() is the primary path).
        if let observer = networkObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        #if os(iOS)
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        #endif
    }

    /// Tear down session and cancel in-flight tasks.
    /// Call from view's onDisappear for full cleanup including URLSession invalidation.
    func cleanup() {
        // MEM-05: Remove background observer to prevent retain cycle / stale notifications.
        #if os(iOS)
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
            backgroundObserver = nil
        }
        #endif
        // NET-RES-1: Remove network observer on teardown.
        if let observer = networkObserver {
            NotificationCenter.default.removeObserver(observer)
            networkObserver = nil
        }
        cancel()
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
        guard let url = URL(string: "\(baseURL)/api/v1/chat/stream") else {
            AppLogger.shared.error("Invalid stream URL: \(baseURL)/api/v1/chat/stream", category: "sse")
            self.error = URLError(.badURL)
            self.isStreaming = false
            return
        }
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
            // Race connection against 60s timeout.
            // CONC-33: Use nonisolated static helper so the TaskGroup.addTask closures
            // are not created in a @MainActor context, avoiding SE-0430 'sending' warnings.
            let urlSession = self.session
            let (asyncBytes, response) = try await Self.fetchBytes(session: urlSession, request: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw APIError.invalidResponse
            }

            connectionState = .connected
            reconnectAttempts = 0

            // CONC-001: Increment generation so any stale watchdog from a prior
            // connection detects the mismatch and exits without cancelling this stream.
            streamGeneration &+= 1
            let currentGeneration = streamGeneration

            // Track last received data or heartbeat for stale connection detection
            let lastActivity = LastActivityTracker()

            // BATT-01: Double watchdog timeout in Low Power Mode (45s -> 90s).
            // Checked once at watchdog creation -- not re-evaluated mid-stream per research.
            let watchdogTimeout: TimeInterval = LowPowerModeMonitor.shared.isLowPowerModeEnabled ? 90 : 45

            // Watchdog: detect stale connections (no data/heartbeat in timeout period).
            // NET-MED-2: Cancels the parent streamTask instead of throwing inside a
            // detached task (thrown errors were silently dropped, leaving stale streams).
            let parentTask = self.streamTask
            // CONC-001: Watchdog checks generation before cancelling to avoid
            // killing a newer stream after reconnect.
            let heartbeatWatchdog = Task.detached { [watchdogTimeout, weak self] in
                while !Task.isCancelled {
                    try await Task.sleep(nanoseconds: 15_000_000_000) // Check every 15s
                    // CONC-001: If generation has advanced, this watchdog is stale — exit.
                    if await self?.streamGeneration != currentGeneration {
                        return
                    }
                    if lastActivity.secondsSinceLastActivity() > watchdogTimeout {
                        AppLogger.shared.warning("SSE heartbeat timeout — no activity in \(Int(watchdogTimeout))s", category: "sse")
                        parentTask?.cancel()
                        return
                    }
                }
            }
            defer { heartbeatWatchdog.cancel() }

            var currentEvent = ""
            var currentData = ""

            for try await line in asyncBytes.lines {
                lastActivity.touch() // Reset on ANY received line

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
        // CON-008: When maxReconnectAttempts is exhausted, do NOT clear currentRequest.
        // Keeping it allows handleNetworkRestoration() to restart the stream when
        // network becomes available again, instead of giving up permanently.
        guard isNetworkError(error) else {
            return false
        }
        guard let request = currentRequest,
              reconnectAttempts < maxReconnectAttempts else {
            if reconnectAttempts >= maxReconnectAttempts {
                AppLogger.shared.warning(
                    "SSE max reconnect attempts (\(maxReconnectAttempts)) reached — " +
                    "stream paused until network restoration",
                    category: "sse"
                )
                // Keep currentRequest intact for network restoration handler.
            }
            return false
        }

        reconnectAttempts += 1
        connectionState = .reconnecting(attempt: reconnectAttempts)

        AppLogger.shared.warning("Reconnection attempt \(reconnectAttempts)/\(maxReconnectAttempts)", category: "sse")

        // NET-002: Exponential backoff capped at 30 seconds with ±25% random jitter
        // to prevent thundering-herd reconnection storms when many clients reconnect simultaneously.
        let baseDelay = min(reconnectDelay * UInt64(1 << (reconnectAttempts - 1)), 30_000_000_000)
        let jitter = Double.random(in: 0.75...1.25)
        let delay = UInt64(Double(baseDelay) * jitter)

        // NET-RES-1: Wrap sleep in a separate task so network restoration can cancel
        // just the backoff without cancelling the parent stream task.
        let sleepTask = Task<Void, Never> {
            try? await Task.sleep(nanoseconds: delay)
        }
        backoffSleepTask = sleepTask
        await sleepTask.value
        let sleepWasCancelled = sleepTask.isCancelled
        backoffSleepTask = nil

        // CON-004: If network restoration cancelled the sleep, reset attempt counter so
        // the next reconnect starts fresh rather than continuing an exhausted backoff sequence.
        if sleepWasCancelled {
            reconnectAttempts = 0
        }

        // Check if parent stream task was cancelled during sleep
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
    var userMessageId: String?
    var assistantMessageId: String?

    private func parseAndAddMessage(event: String, data: String) async {
        // Handle special event types
        switch event {
        case "done":
            AppLogger.shared.info("Received done event — stream complete", category: "sse")
            isStreaming = false
            connectionState = .connected
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

    /// CONC-33: nonisolated static helper so TaskGroup.addTask closures are NOT created
    /// in a @MainActor context, eliminating SE-0430 'sending' warnings at the addTask call site.
    /// URLSession and URLRequest are both Sendable so passing them across the actor boundary is safe.
    nonisolated private static func fetchBytes(
        session: URLSession,
        request: URLRequest
    ) async throws -> (URLSession.AsyncBytes, URLResponse) {
        try await withThrowingTaskGroup(of: (URLSession.AsyncBytes, URLResponse).self) { group in
            // Connection task
            group.addTask {
                try await session.bytes(for: request)
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
    }

    /// Cancel the current stream
    func cancel() {
        backoffSleepTask?.cancel()
        backoffSleepTask = nil
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

    // MARK: - Network Restoration

    /// NET-RES-1: Called when network becomes available — skip any active backoff
    /// sleep for immediate reconnection, or restart a stopped stream.
    private func handleNetworkRestoration() {
        if backoffSleepTask != nil {
            // Currently in a backoff wait — cancel the sleep so performStream
            // proceeds immediately on the next iteration.
            AppLogger.shared.info("Network restored — skipping SSE backoff sleep", category: "sse")
            backoffSleepTask?.cancel()
            backoffSleepTask = nil
        } else if !isStreaming, currentRequest != nil {
            // All reconnect attempts were exhausted but the user hasn't explicitly
            // cancelled — restart the stream now that network is back.
            AppLogger.shared.info("Network restored — restarting stopped SSE stream", category: "sse")
            resetAndReconnect()
        }
    }

    /// Externally trigger an immediate reconnection for the current request.
    /// Cancels any active backoff sleep so reconnection starts without delay.
    /// If the stream was fully stopped (all attempts exhausted), restarts it.
    func resetAndReconnect() {
        // Cancel any active backoff sleep — performStream will proceed after sleep exits.
        backoffSleepTask?.cancel()
        backoffSleepTask = nil

        guard let request = currentRequest else { return }

        if !isStreaming {
            // Stream was fully stopped — restart from scratch with a fresh attempt counter.
            AppLogger.shared.info("resetAndReconnect — restarting stream from scratch", category: "sse")
            reconnectAttempts = 0
            isStreaming = true
            error = nil
            connectionState = .connecting
            streamTask = Task { [weak self] in
                await self?.performStream(request: request)
            }
        }
        // If isStreaming is true and we're in backoff, cancelling backoffSleepTask
        // above is sufficient — performStream continues after the sleep exits.
    }
}

/// Thread-safe tracker for last SSE activity timestamp.
/// Uses OSAllocatedUnfairLock instead of actor to avoid actor-hop overhead
/// on every received SSE line (hot path during streaming).
private final class LastActivityTracker: Sendable {
    private let storage = OSAllocatedUnfairLock(initialState: Date())

    func touch() {
        storage.withLock { $0 = Date() }
    }

    func secondsSinceLastActivity() -> TimeInterval {
        let last = storage.withLock { $0 }
        return Date().timeIntervalSince(last)
    }
}
