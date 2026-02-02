import Vapor
import ILSShared

/// Service for handling SSE streaming responses
struct StreamingService {
    /// Create an SSE response from an async stream of messages
    static func createSSEResponse(
        from stream: AsyncThrowingStream<StreamMessage, Error>,
        on request: Request
    ) -> Response {
        let response = Response(status: .ok)
        response.headers.contentType = HTTPMediaType(type: "text", subType: "event-stream")
        response.headers.add(name: .cacheControl, value: "no-cache")
        response.headers.add(name: .connection, value: "keep-alive")

        response.body = .init(asyncStream: { writer in
            do {
                for try await message in stream {
                    let eventData = try formatSSEEvent(message)
                    try await writer.write(.buffer(.init(string: eventData)))
                }
                try await writer.write(.end)
            } catch {
                let errorEvent = try? formatSSEEvent(.error(StreamError(
                    code: "STREAM_ERROR",
                    message: error.localizedDescription
                )))
                if let errorEvent = errorEvent {
                    try? await writer.write(.buffer(.init(string: errorEvent)))
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

    /// Send a keep-alive ping
    static func createPingEvent() -> String {
        return ": ping\n\n"
    }
}
