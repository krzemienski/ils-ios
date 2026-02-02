import Vapor
import ILSShared

/// Service for handling SSE streaming responses
struct StreamingService {
    /// Heartbeat interval in seconds
    private static let heartbeatInterval: UInt64 = 15_000_000_000 // 15 seconds in nanoseconds

    /// Create an SSE response from an async stream of messages
    /// Includes automatic heartbeat events to keep connection alive
    static func createSSEResponse(
        from stream: AsyncThrowingStream<StreamMessage, Error>,
        on request: Request
    ) -> Response {
        let response = Response(status: .ok)
        response.headers.contentType = HTTPMediaType(type: "text", subType: "event-stream")
        response.headers.add(name: .cacheControl, value: "no-cache")
        response.headers.add(name: .connection, value: "keep-alive")
        response.headers.add(name: "X-Accel-Buffering", value: "no") // Disable nginx buffering

        response.body = .init(asyncStream: { writer in
            // Track if client is still connected
            var isConnected = true

            // Create a task for sending heartbeats
            let heartbeatTask = Task {
                while !Task.isCancelled && isConnected {
                    try await Task.sleep(nanoseconds: heartbeatInterval)
                    guard !Task.isCancelled && isConnected else { break }
                    do {
                        try await writer.write(.buffer(.init(string: createPingEvent())))
                    } catch {
                        // Client likely disconnected
                        isConnected = false
                        break
                    }
                }
            }

            defer {
                heartbeatTask.cancel()
            }

            do {
                for try await message in stream {
                    guard isConnected else { break }

                    let eventData = try formatSSEEvent(message)
                    do {
                        try await writer.write(.buffer(.init(string: eventData)))
                    } catch {
                        // Write failed - client likely disconnected
                        isConnected = false
                        request.logger.debug("SSE client disconnected during write")
                        break
                    }
                }

                // Send completion event if client still connected
                if isConnected {
                    let doneEvent = "event: done\ndata: {}\n\n"
                    try? await writer.write(.buffer(.init(string: doneEvent)))
                }

                try await writer.write(.end)
            } catch is CancellationError {
                // Stream was cancelled (client disconnected)
                request.logger.debug("SSE stream cancelled - client disconnected")
                try? await writer.write(.end)
            } catch {
                // Handle stream errors
                request.logger.error("SSE stream error: \(error.localizedDescription)")

                if isConnected {
                    let errorEvent = try? formatSSEEvent(.error(StreamError(
                        code: "STREAM_ERROR",
                        message: error.localizedDescription
                    )))
                    if let errorEvent = errorEvent {
                        try? await writer.write(.buffer(.init(string: errorEvent)))
                    }
                }
                try? await writer.write(.end)
            }
        })

        return response
    }

    /// Format a StreamMessage as an SSE event
    private static func formatSSEEvent(_ message: StreamMessage) throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw Abort(.internalServerError, reason: "Failed to encode message")
        }

        let eventType: String
        switch message {
        case .system:
            eventType = "system"
        case .assistant:
            eventType = "assistant"
        case .result:
            eventType = "result"
        case .permission:
            eventType = "permission"
        case .error:
            eventType = "error"
        }

        return "event: \(eventType)\ndata: \(jsonString)\n\n"
    }

    /// Send a keep-alive ping (SSE comment format)
    static func createPingEvent() -> String {
        return ": ping\n\n"
    }
}
