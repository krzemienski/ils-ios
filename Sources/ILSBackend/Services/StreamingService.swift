import Vapor
import Fluent
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

    /// Create an SSE response with message persistence
    /// Accumulates assistant response content and saves to database on stream completion
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
        // Include message IDs in response headers for client correlation
        response.headers.add(name: "X-User-Message-ID", value: userMessageId.uuidString)
        response.headers.add(name: "X-Session-ID", value: sessionId.uuidString)

        response.body = .init(asyncStream: { writer in
            var isConnected = true
            var accumulatedContent = ""
            var toolCalls: [String] = []
            var toolResults: [String] = []
            var claudeSessionId: String?
            var totalCostUSD: Double?

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

            defer {
                heartbeatTask.cancel()
            }

            do {
                for try await message in stream {
                    guard isConnected else { break }

                    // Accumulate content based on message type
                    switch message {
                    case .system(let systemMsg):
                        claudeSessionId = systemMsg.data.sessionId

                    case .assistant(let assistantMsg):
                        for block in assistantMsg.content {
                            switch block {
                            case .text(let textBlock):
                                accumulatedContent += textBlock.text
                            case .toolUse(let toolUseBlock):
                                if let jsonData = try? JSONEncoder().encode(toolUseBlock),
                                   let jsonString = String(data: jsonData, encoding: .utf8) {
                                    toolCalls.append(jsonString)
                                }
                            case .toolResult(let toolResultBlock):
                                if let jsonData = try? JSONEncoder().encode(toolResultBlock),
                                   let jsonString = String(data: jsonData, encoding: .utf8) {
                                    toolResults.append(jsonString)
                                }
                            case .thinking:
                                // Don't persist thinking blocks
                                break
                            }
                        }

                    case .result(let resultMsg):
                        claudeSessionId = resultMsg.sessionId
                        totalCostUSD = resultMsg.totalCostUSD

                    case .permission, .error:
                        break
                    }

                    let eventData = try formatSSEEvent(message)
                    do {
                        try await writer.write(.buffer(.init(string: eventData)))
                    } catch {
                        isConnected = false
                        request.logger.debug("SSE client disconnected during write")
                        break
                    }
                }

                // Save assistant message to database on stream completion
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

                if isConnected {
                    let doneEvent = "event: done\ndata: {}\n\n"
                    try? await writer.write(.buffer(.init(string: doneEvent)))
                }

                try await writer.write(.end)
            } catch is CancellationError {
                request.logger.debug("SSE stream cancelled - client disconnected")

                // Still try to save partial content
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

                try? await writer.write(.end)
            } catch {
                request.logger.error("SSE stream error: \(error.localizedDescription)")

                // Save partial content on error
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
