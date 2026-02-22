import Foundation
import Observation
import ILSShared

/// WebSocket client for live system metrics streaming.
/// Falls back to REST polling if WebSocket fails 3 times.
@MainActor
@Observable
final class MetricsWebSocketClient {
    var latestMetrics: SystemMetricsResponse?
    var isConnected: Bool = false

    /// Sliding window of recent data points for charts (max 60).
    var cpuHistory: [MetricDataPoint] = []
    var memoryHistory: [MetricDataPoint] = []
    var diskHistory: [MetricDataPoint] = []
    var networkInHistory: [MetricDataPoint] = []
    var networkOutHistory: [MetricDataPoint] = []

    let baseURL: String
    nonisolated(unsafe) private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession
    private let decoder: JSONDecoder

    private var reconnectAttempts: Int = 0
    private var wsFailureCount: Int = 0
    private let maxWSFailures: Int = 3
    private let maxHistorySize: Int = 60

    nonisolated(unsafe) private var reconnectTask: Task<Void, Never>?
    nonisolated(unsafe) private var pollingTask: Task<Void, Never>?
    nonisolated(unsafe) private var receiveTask: Task<Void, Never>?
    nonisolated(unsafe) private var heartbeatTask: Task<Void, Never>?
    private var useFallbackPolling: Bool = false
    private var lastWSResetTime: Date?
    private let wsResetInterval: TimeInterval = 600
    private let heartbeatInterval: TimeInterval = 15 // Send ping every 15 seconds

    init(baseURL: String = "http://localhost:9999") {
        self.baseURL = baseURL
        self.session = URLSession(configuration: .default)
        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    deinit {
        reconnectTask?.cancel()
        pollingTask?.cancel()
        receiveTask?.cancel()
        heartbeatTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }

    // MARK: - Public API

    func connect() {
        guard webSocketTask == nil, pollingTask == nil else { return }

        // Reset fallback after recovery window (10 minutes) to retry WebSocket
        if useFallbackPolling,
           let resetTime = lastWSResetTime,
           Date().timeIntervalSince(resetTime) > wsResetInterval {
            useFallbackPolling = false
            wsFailureCount = 0
        }

        if useFallbackPolling {
            startPolling()
        } else {
            connectWebSocket()
        }
    }

    func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        pollingTask?.cancel()
        pollingTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        // Reset failure state so a subsequent connect() starts fresh (MEMORY.md bug fix)
        wsFailureCount = 0
        reconnectAttempts = 0
        useFallbackPolling = false
    }

    // MARK: - WebSocket

    private func connectWebSocket() {
        // Build WS URL: ws://host:port/api/v1/system/metrics/live
        let wsURLString = baseURL
            .replacingOccurrences(of: "http://", with: "ws://")
            .replacingOccurrences(of: "https://", with: "wss://")
        + "/api/v1/system/metrics/live"

        guard let url = URL(string: wsURLString) else { return }

        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

        isConnected = true
        reconnectAttempts = 0

        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }

        // Start heartbeat to detect stale connections
        startHeartbeat()
    }

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self.heartbeatInterval * 1_000_000_000))
                guard !Task.isCancelled else { return }
                guard let wsTask = self.webSocketTask else { return }
                // Send a ping; if pong is not received the connection is stale
                let pingSucceeded = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                    wsTask.sendPing { error in
                        cont.resume(returning: error == nil)
                    }
                }
                if !pingSucceeded {
                    await self.handleWSDisconnect()
                    return
                }
            }
        }
    }

    private func receiveLoop() async {
        guard let task = webSocketTask else { return }

        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8) {
                        try handleMetricsData(data)
                    }
                case .data(let data):
                    try handleMetricsData(data)
                @unknown default:
                    break
                }
            } catch {
                if !Task.isCancelled {
                    await handleWSDisconnect()
                }
                return
            }
        }
    }

    private func handleMetricsData(_ data: Data) throws {
        let metrics = try decoder.decode(SystemMetricsResponse.self, from: data)
        let now = Date()

        latestMetrics = metrics

        appendDataPoint(to: &cpuHistory, value: metrics.cpu, at: now)
        appendDataPoint(to: &memoryHistory, value: metrics.memory.percentage, at: now)
        appendDataPoint(to: &diskHistory, value: metrics.disk.percentage, at: now)
        appendDataPoint(to: &networkInHistory, value: Double(metrics.network.bytesIn), at: now)
        appendDataPoint(to: &networkOutHistory, value: Double(metrics.network.bytesOut), at: now)
    }

    private func appendDataPoint(to history: inout [MetricDataPoint], value: Double, at date: Date) {
        history.append(MetricDataPoint(timestamp: date, value: value))
        // Only ever 1 excess element since we append 1 at a time.
        // removeFirst() on a 61-element array is O(60) but acceptable
        // for this tick rate. Full Deque migration is a future optimization.
        if history.count > maxHistorySize {
            history.removeFirst()
        }
    }

    private func handleWSDisconnect() async {
        isConnected = false
        heartbeatTask?.cancel()
        heartbeatTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        wsFailureCount += 1

        if wsFailureCount >= maxWSFailures {
            useFallbackPolling = true
            lastWSResetTime = Date()
            startPolling()
            return
        }

        scheduleReconnect()
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        reconnectAttempts += 1
        let delay = min(Double(1 << reconnectAttempts), 30.0) // 1s, 2s, 4s, ... max 30s

        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.connectWebSocket()
        }
    }

    // MARK: - Fallback REST Polling

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.pollMetrics()
                try? await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
            }
        }
    }

    private func pollMetrics() async {
        guard let url = URL(string: "\(baseURL)/api/v1/system/metrics") else { return }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                isConnected = false
                return
            }
            try handleMetricsData(data)
            isConnected = true
        } catch {
            isConnected = false
        }
    }
}
