import Foundation
import ILSShared

/// WebSocket client for streaming terminal command output in real time.
/// Each `execute(_:)` call opens a connection, sends the command, streams
/// `TerminalStreamMessage` events to the provided callback, then closes.
@MainActor
final class TerminalWebSocketClient {
    // MARK: - Public State

    var isConnected: Bool = false

    // MARK: - Private

    let baseURL: String
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Active streaming task; cancelled on disconnect.
    // @ObservationIgnored not needed here (non-Observable class), but
    // kept nonisolated-accessible via Task.cancel() for safety-net deinit.
    private var receiveTask: Task<Void, Never>?

    init(baseURL: String = ConnectionDefaults.defaultURL) {
        self.baseURL = baseURL
        self.session = URLSession(configuration: .default)
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    /// Safety-net deinit: cancels receive task if cleanup() was not called.
    deinit {
        receiveTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }

    // MARK: - Public API

    /// Streams the output of a shell command via WebSocket.
    ///
    /// Opens a WebSocket connection to `/api/v1/terminal/stream`, sends the
    /// given `request` as JSON, then calls `onMessage` for every
    /// `TerminalStreamMessage` received.  The stream ends automatically when
    /// the server sends an `.exit` message or when the connection is closed.
    ///
    /// - Parameters:
    ///   - request: The terminal execute request (command + optional env).
    ///   - onMessage: Callback invoked on the MainActor for each streamed chunk.
    func execute(
        _ request: TerminalExecuteRequest,
        onMessage: @escaping @MainActor (TerminalStreamMessage) -> Void
    ) async throws {
        // Tear down any existing connection before starting a new one.
        disconnect()

        let wsURLString = baseURL
            .replacingOccurrences(of: "http://", with: "ws://")
            .replacingOccurrences(of: "https://", with: "wss://")
            + "/api/v1/terminal/stream"

        guard let url = URL(string: wsURLString) else {
            throw TerminalWebSocketError.invalidURL(wsURLString)
        }

        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true

        // Send the execute request as JSON immediately after connecting.
        let requestData = try encoder.encode(request)
        guard let requestJSON = String(data: requestData, encoding: .utf8) else {
            throw TerminalWebSocketError.encodingFailed
        }
        try await webSocketTask?.send(.string(requestJSON))

        // Stream messages until exit or connection close.
        await receiveAll(onMessage: onMessage)
    }

    /// Cancels any active command stream and closes the WebSocket connection.
    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    // MARK: - Private Receive Loop

    private func receiveAll(
        onMessage: @escaping @MainActor (TerminalStreamMessage) -> Void
    ) async {
        guard let task = webSocketTask else { return }

        while !Task.isCancelled {
            do {
                let raw = try await task.receive()
                let data: Data
                switch raw {
                case .string(let text):
                    guard let encoded = text.data(using: .utf8) else { continue }
                    data = encoded
                case .data(let bytes):
                    data = bytes
                @unknown default:
                    continue
                }

                let message = try decoder.decode(TerminalStreamMessage.self, from: data)
                onMessage(message)

                // Server signals command completion via an `.exit` message.
                if message.type == .exit {
                    break
                }
            } catch {
                // Connection closed or decoding failed — stop the loop.
                break
            }
        }

        isConnected = false
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
    }
}

// MARK: - Errors

enum TerminalWebSocketError: LocalizedError {
    case invalidURL(String)
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid WebSocket URL: \(url)"
        case .encodingFailed:
            return "Failed to encode terminal request as JSON."
        }
    }
}
