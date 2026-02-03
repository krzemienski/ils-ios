import Vapor
import ILSShared

/// Service for handling WebSocket connections
actor WebSocketService {
    private var connections: [String: WebSocket] = [:]
    private let executor: ClaudeExecutorService
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(executor: ClaudeExecutorService) {
        self.executor = executor

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    /// Handle a new WebSocket connection
    func handleConnection(
        _ ws: WebSocket,
        sessionId: String,
        projectPath: String?,
        on request: Request
    ) async {
        connections[sessionId] = ws

        ws.onText { [weak self] ws, text in
            guard let self = self else { return }
            Task {
                await self.handleMessage(text, sessionId: sessionId, projectPath: projectPath, ws: ws)
            }
        }

        ws.onClose.whenComplete { [weak self] _ in
            Task {
                await self?.removeConnection(sessionId)
            }
        }
    }

    private func handleMessage(
        _ text: String,
        sessionId: String,
        projectPath: String?,
        ws: WebSocket
    ) async {
        guard let data = text.data(using: .utf8) else { return }

        do {
            let message = try decoder.decode(WSClientMessage.self, from: data)

            switch message {
            case .message(let prompt):
                await handlePrompt(prompt, sessionId: sessionId, projectPath: projectPath, ws: ws)

            case .permission(let requestId, let decision, let reason):
                await handlePermissionDecision(requestId: requestId, decision: decision, reason: reason)

            case .cancel:
                await executor.cancel(sessionId: sessionId)
                try? await sendMessage(.complete(ResultMessage(
                    sessionId: sessionId,
                    isError: false
                )), to: ws)
            }
        } catch {
            try? await sendMessage(.error(StreamError(
                code: "PARSE_ERROR",
                message: "Failed to parse message: \(error.localizedDescription)"
            )), to: ws)
        }
    }

    private func handlePrompt(
        _ prompt: String,
        sessionId: String,
        projectPath: String?,
        ws: WebSocket
    ) async {
        var options = ExecutionOptions()
        options.sessionId = sessionId
        options.resume = sessionId

        let stream = executor.execute(
            prompt: prompt,
            workingDirectory: projectPath,
            options: options
        )

        do {
            for try await message in stream {
                try await sendMessage(.stream(message), to: ws)
            }
        } catch {
            try? await sendMessage(.error(StreamError(
                code: "EXECUTION_ERROR",
                message: error.localizedDescription
            )), to: ws)
        }
    }

    private func handlePermissionDecision(
        requestId: String,
        decision: String,
        reason: String?
    ) async {
        // In a real implementation, this would send the decision to Claude CLI
        // For now, we just acknowledge it
        print("Permission decision for \(requestId): \(decision)")
    }

    private func sendMessage(_ message: WSServerMessage, to ws: WebSocket) async throws {
        let data = try encoder.encode(message)
        guard let text = String(data: data, encoding: .utf8) else {
            throw Abort(.internalServerError, reason: "Failed to encode message")
        }
        try await ws.send(text)
    }

    private func removeConnection(_ sessionId: String) {
        connections.removeValue(forKey: sessionId)
    }

    /// Get connection count
    func connectionCount() -> Int {
        return connections.count
    }
}
