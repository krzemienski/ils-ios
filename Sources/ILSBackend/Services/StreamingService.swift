import Vapor
import Fluent
import ILSShared

/// Thread-safe monotonically increasing event counter
actor EventCounter {
    private var current: Int = 0
    func next() -> Int {
        current += 1
        return current
    }
}

/// Ring buffer storing recent SSE events for replay on reconnect
actor EventBuffer {
    private var buffer: [(id: Int, data: String)] = []
    private let capacity = 1000

    func store(id: Int, data: String) {
        buffer.append((id: id, data: data))
        if buffer.count > capacity {
            buffer.removeFirst(buffer.count - capacity)
        }
    }

    func eventsSince(_ lastId: Int) -> [(id: Int, data: String)] {
        buffer.filter { $0.id > lastId }
    }
}

/// Service for handling Server-Sent Events (SSE) streaming responses.
///
/// Converts AsyncThrowingStream of StreamMessage into HTTP SSE responses with:
/// - Automatic heartbeat/ping events (every 15s)
/// - Error handling and propagation
/// - Optional message persistence to database
/// - Client disconnection detection
/// - Event IDs and ring buffer for reconnection replay
struct StreamingService {
    /// Shared event counter for all SSE streams
    static let eventCounter = EventCounter()
    /// Shared event buffer for reconnection replay
    static let eventBuffer = EventBuffer()
    /// Shared JSON encoder for all SSE formatting
    private static let jsonEncoder = JSONEncoder()

    /// Heartbeat interval in nanoseconds (15 seconds)
    private static let heartbeatInterval: UInt64 = 15_000_000_000

    /// Shared streaming logic for both simple and persistent SSE responses.
    ///
    /// Handles:
    /// - Last-Event-ID parsing and event replay from ring buffer
    /// - Heartbeat pings every 15 seconds
    /// - Event ID assignment and buffer storage
    /// - Client disconnection detection
    /// - Error propagation
    ///
    /// - Parameters:
    ///   - stream: AsyncThrowingStream of StreamMessage events
    ///   - writer: Response body writer
    ///   - request: Vapor Request for logging and Last-Event-ID header
    ///   - onMessage: Optional closure called for each message (for persistence)
    private static func writeSSEStream(
        from stream: AsyncThrowingStream<StreamMessage, Error>,
        writer: Response.Body.AsyncWriter,
        request: Request,
        onMessage: ((StreamMessage) -> Void)? = nil
    ) async throws {
        var isConnected = true

        // Parse Last-Event-ID for replay
        if let lastEventIdStr = request.headers.first(name: "Last-Event-ID"),
           let lastEventId = Int(lastEventIdStr) {
            let missedEvents = await eventBuffer.eventsSince(lastEventId)
            for event in missedEvents {
                try await writer.write(.buffer(.init(string: event.data)))
            }
        }

        let heartbeatTask = Task {
            while !Task.isCancelled && isConnected {
                try await Task.sleep(nanoseconds: heartbeatInterval)
                guard !Task.isCancelled && isConnected else { break }
                do {
                    try await writer.write(.buffer(.init(string: createPingEvent())))
                } catch {
                    isConnected = false
                    break
                }
            }
        }

        defer { heartbeatTask.cancel() }

        do {
            for try await message in stream {
                guard isConnected else { break }

                onMessage?(message)

                let eventId = await eventCounter.next()
                let eventData = try formatSSEEvent(message, eventId: eventId)
                await eventBuffer.store(id: eventId, data: eventData)

                do {
                    try await writer.write(.buffer(.init(string: eventData)))
                } catch {
                    isConnected = false
                    request.logger.debug("SSE client disconnected during write")
                    break
                }
            }

            if isConnected {
                let doneEvent = "event: done\ndata: {}\n\n"
                try? await writer.write(.buffer(.init(string: doneEvent)))
            }
            try await writer.write(.end)
        } catch is CancellationError {
            request.logger.debug("SSE stream cancelled - client disconnected")
            try? await writer.write(.end)
        } catch {
            request.logger.error("SSE stream error: \(error.localizedDescription)")
            if isConnected {
                let errorEvent = try? formatSSEEvent(.error(StreamError(
                    code: "STREAM_ERROR",
                    message: error.localizedDescription
                )), eventId: await eventCounter.next())
                if let errorEvent {
                    try? await writer.write(.buffer(.init(string: errorEvent)))
                }
            }
            try? await writer.write(.end)
        }
    }

    /// Create an SSE response from an async stream of messages.
    ///
    /// Automatically sends heartbeat pings every 15 seconds to keep connection alive.
    /// Supports event replay via Last-Event-ID header.
    ///
    /// - Parameters:
    ///   - stream: AsyncThrowingStream of StreamMessage events
    ///   - request: Vapor Request for logging and context
    /// - Returns: Vapor Response with SSE content type
    static func createSSEResponse(
        from stream: AsyncThrowingStream<StreamMessage, Error>,
        on request: Request
    ) -> Response {
        let response = Response(status: .ok)
        response.headers.contentType = HTTPMediaType(type: "text", subType: "event-stream")
        response.headers.add(name: .cacheControl, value: "no-cache")
        response.headers.add(name: .connection, value: "keep-alive")
        response.headers.add(name: "X-Accel-Buffering", value: "no")

        response.body = .init(asyncStream: { writer in
            try await writeSSEStream(from: stream, writer: writer, request: request)
        })

        return response
    }

    /// Create an SSE response with message persistence to database.
    ///
    /// Accumulates assistant response content (text, tool calls, tool results) during streaming
    /// and saves to database on stream completion. Updates session metadata (message count, cost).
    ///
    /// - Parameters:
    ///   - stream: AsyncThrowingStream of StreamMessage events
    ///   - sessionId: Session UUID for database association
    ///   - userMessageId: User message UUID for correlation
    ///   - request: Vapor Request for database access and logging
    /// - Returns: Vapor Response with SSE content type and message ID headers
    static func createSSEResponseWithPersistence(
        from stream: AsyncThrowingStream<StreamMessage, Error>,
        sessionId: UUID,
        userMessageId: UUID,
        on request: Request
    ) -> Response {
        let response = Response(status: .ok)
        response.headers.contentType = HTTPMediaType(type: "text", subType: "event-stream")
        response.headers.add(name: .cacheControl, value: "no-cache")
        response.headers.add(name: .connection, value: "keep-alive")
        response.headers.add(name: "X-Accel-Buffering", value: "no")
        response.headers.add(name: "X-User-Message-ID", value: userMessageId.uuidString)
        response.headers.add(name: "X-Session-ID", value: sessionId.uuidString)

        response.body = .init(asyncStream: { writer in
            var accumulatedContent = ""
            var toolCalls: [String] = []
            var toolResults: [String] = []
            var claudeSessionId: String?
            var totalCostUSD: Double?

            // Accumulate content during streaming
            let onMessage: (StreamMessage) -> Void = { message in
                switch message {
                case .system(let systemMsg):
                    claudeSessionId = systemMsg.data.sessionId

                case .assistant(let assistantMsg):
                    for block in assistantMsg.content {
                        switch block {
                        case .text(let textBlock):
                            accumulatedContent += textBlock.text
                        case .toolUse(let toolUseBlock):
                            if let jsonData = try? Self.jsonEncoder.encode(toolUseBlock),
                               let jsonString = String(data: jsonData, encoding: .utf8) {
                                toolCalls.append(jsonString)
                            }
                        case .toolResult(let toolResultBlock):
                            if let jsonData = try? Self.jsonEncoder.encode(toolResultBlock),
                               let jsonString = String(data: jsonData, encoding: .utf8) {
                                toolResults.append(jsonString)
                            }
                        case .thinking:
                            break
                        }
                    }

                case .result(let resultMsg):
                    claudeSessionId = resultMsg.sessionId
                    totalCostUSD = resultMsg.totalCostUSD

                case .permission, .error:
                    break
                }
            }

            do {
                // Use shared streaming logic
                try await writeSSEStream(from: stream, writer: writer, request: request, onMessage: onMessage)

                // Save assistant message to database after stream completion
                if !accumulatedContent.isEmpty {
                    let assistantMessage = MessageModel(
                        sessionId: sessionId,
                        role: .assistant,
                        content: accumulatedContent,
                        toolCalls: toolCalls.isEmpty ? nil : "[\(toolCalls.joined(separator: ","))]",
                        toolResults: toolResults.isEmpty ? nil : "[\(toolResults.joined(separator: ","))]"
                    )
                    try? await assistantMessage.save(on: request.db)

                    // Update session with Claude session ID and cost
                    if let session = try? await SessionModel.find(sessionId, on: request.db) {
                        if let claudeId = claudeSessionId {
                            session.claudeSessionId = claudeId
                        }
                        session.messageCount += 1
                        if let cost = totalCostUSD {
                            session.totalCostUSD = (session.totalCostUSD ?? 0) + cost
                        }
                        try? await session.save(on: request.db)
                    }

                    // Send message ID in a custom event for client correlation
                    if let msgId = assistantMessage.id {
                        let idEvent = "event: messageId\ndata: {\"userMessageId\":\"\(userMessageId.uuidString)\",\"assistantMessageId\":\"\(msgId.uuidString)\"}\n\n"
                        try? await writer.write(.buffer(.init(string: idEvent)))
                    }
                }
            } catch {
                // Save partial content on any error
                if !accumulatedContent.isEmpty {
                    let assistantMessage = MessageModel(
                        sessionId: sessionId,
                        role: .assistant,
                        content: accumulatedContent,
                        toolCalls: toolCalls.isEmpty ? nil : "[\(toolCalls.joined(separator: ","))]",
                        toolResults: toolResults.isEmpty ? nil : "[\(toolResults.joined(separator: ","))]"
                    )
                    try? await assistantMessage.save(on: request.db)
                }
                throw error
            }
        })

        return response
    }

    /// Format a StreamMessage as an SSE event with event type, ID, and JSON data.
    /// - Parameters:
    ///   - message: StreamMessage to format
    ///   - eventId: Unique event ID for replay support
    /// - Returns: SSE-formatted string (e.g., "id: 1\nevent: assistant\ndata: {...}\n\n")
    private static func formatSSEEvent(_ message: StreamMessage, eventId: Int) throws -> String {
        let data = try jsonEncoder.encode(message)
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

        return "id: \(eventId)\nevent: \(eventType)\ndata: \(jsonString)\n\n"
    }

    /// Create a keep-alive ping event in SSE comment format.
    /// - Returns: SSE comment string (": ping\n\n")
    static func createPingEvent() -> String {
        return ": ping\n\n"
    }
}
