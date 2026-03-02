import Vapor
import Fluent
import ILSShared

/// Controller providing a unified cross-session activity feed.
///
/// Routes:
/// - `GET /activity/events`: REST polling — returns filtered, paginated activity events
/// - `GET /activity/events/stream`: SSE streaming — real-time event updates via Server-Sent Events
struct ActivityFeedController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let activity = routes.grouped("activity")
        activity.get("events", use: events)
        activity.get("events", "stream", use: stream)
    }

    // MARK: - REST Polling

    /// GET /activity/events
    ///
    /// Returns recent activity events derived from DB sessions and messages.
    ///
    /// Query parameters:
    /// - `limit`: Maximum events to return (default: 50, max: 200)
    /// - `since`: ISO 8601 cursor — only events after this date
    /// - `eventType`: Comma-separated list of `ActivityEventType` raw values
    /// - `sessionId`: UUID string — restrict to a single session
    /// - `projectName`: Project name string — restrict to sessions in this project
    /// - `severity`: `info`, `warning`, or `error`
    @Sendable
    func events(req: Request) async throws -> APIResponse<ActivityFeedResponse> {
        let limit = min((req.query["limit"] as Int?) ?? 50, 200)
        let sinceString: String? = req.query["since"]
        let eventTypeString: String? = req.query["eventType"]
        let sessionIdString: String? = req.query["sessionId"]
        let projectNameFilter: String? = req.query["projectName"]
        let severityString: String? = req.query["severity"]

        let since = sinceString.flatMap(parseISO8601)
        let eventTypeFilter: [ActivityEventType]? = eventTypeString.map { str in
            str.split(separator: ",").compactMap {
                ActivityEventType(rawValue: String($0).trimmingCharacters(in: .whitespaces))
            }
        }
        let severityFilter = severityString.flatMap { ActivityEventSeverity(rawValue: $0) }
        let sessionIdFilter = sessionIdString.flatMap { UUID(uuidString: $0) }

        var allEvents = try await fetchEvents(
            since: since,
            sessionIdFilter: sessionIdFilter,
            projectNameFilter: projectNameFilter,
            on: req
        )

        // Apply in-memory filters
        if let types = eventTypeFilter, !types.isEmpty {
            allEvents = allEvents.filter { types.contains($0.eventType) }
        }
        if let sev = severityFilter {
            allEvents = allEvents.filter { $0.severity == sev }
        }

        let total = allEvents.count
        let page = Array(allEvents.prefix(limit))

        return APIResponse(
            success: true,
            data: ActivityFeedResponse(
                events: page,
                totalCount: total,
                unreadCount: total,
                hasMore: total > limit
            )
        )
    }

    // MARK: - SSE Streaming

    /// GET /activity/events/stream
    ///
    /// Server-Sent Events stream that polls the DB every 5 s for new activity events.
    /// Sends a `:heartbeat` comment every 15 s to keep the connection alive.
    /// Terminates gracefully when the client disconnects.
    @Sendable
    func stream(req: Request) async throws -> Response {
        let response = Response(status: .ok)
        response.headers.replaceOrAdd(name: .contentType, value: "text/event-stream")
        response.headers.replaceOrAdd(name: .cacheControl, value: "no-cache")
        response.headers.replaceOrAdd(name: "Connection", value: "keep-alive")
        response.headers.replaceOrAdd(name: "X-Accel-Buffering", value: "no")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        response.body = .init(asyncStream: { writer in
            // Start cursor at "now" so only future events are emitted
            var lastSince = Date().addingTimeInterval(-1)
            var lastHeartbeat = Date()

            mainLoop: while true {
                do {
                    let newEvents = try await self.fetchEvents(
                        since: lastSince,
                        sessionIdFilter: nil,
                        projectNameFilter: nil,
                        on: req
                    )

                    if !newEvents.isEmpty {
                        if let maxDate = newEvents.map(\.timestamp).max() {
                            lastSince = maxDate
                        }
                        for event in newEvents {
                            let data = try encoder.encode(event)
                            if let json = String(data: data, encoding: .utf8) {
                                try await writer.write(.buffer(.init(string: "data: \(json)\n\n")))
                            }
                        }
                    }

                    // Heartbeat every 15 s
                    let now = Date()
                    if now.timeIntervalSince(lastHeartbeat) >= 15 {
                        try await writer.write(.buffer(.init(string: ":heartbeat\n\n")))
                        lastHeartbeat = now
                    }
                } catch {
                    // Client disconnected or unrecoverable error — end stream
                    break mainLoop
                }

                // Poll interval: 5 s
                do {
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                } catch {
                    break mainLoop
                }
            }

            try? await writer.write(.end)
        })

        return response
    }

    // MARK: - Private Helpers

    /// Fetch and convert DB sessions + messages into ActivityEvent array.
    ///
    /// - Parameters:
    ///   - since: Only include events strictly after this date.
    ///   - sessionIdFilter: Restrict to a single session UUID.
    ///   - projectNameFilter: Restrict to sessions belonging to this project.
    ///   - req: Vapor request (provides db access).
    private func fetchEvents(
        since: Date?,
        sessionIdFilter: UUID?,
        projectNameFilter: String?,
        on req: Request
    ) async throws -> [ActivityEvent] {

        // Load up to 200 recent sessions with their projects
        let sessions = try await SessionModel.query(on: req.db)
            .with(\.$project)
            .sort(\.$lastActiveAt, .descending)
            .limit(200)
            .all()

        // Build a lookup: sessionId → (name, projectName)
        var sessionLookup: [UUID: (name: String?, projectName: String?)] = [:]
        for s in sessions {
            guard let sid = s.id else { continue }
            sessionLookup[sid] = (name: s.name, projectName: s.project?.name)
        }

        // Apply project / session filters to determine which sessions are in scope
        var targetSessions = sessions
        if let projFilter = projectNameFilter {
            targetSessions = targetSessions.filter { $0.project?.name == projFilter }
        }
        if let sid = sessionIdFilter {
            targetSessions = targetSessions.filter { $0.id == sid }
        }

        // Short-circuit when filters produce no matching sessions
        guard !targetSessions.isEmpty else { return [] }

        let targetSessionIds = Set(targetSessions.compactMap(\.id))

        var events: [ActivityEvent] = []

        // --- Session-created events ---
        for session in targetSessions {
            guard let sid = session.id,
                  let createdAt = session.createdAt else { continue }
            if let cutoff = since, createdAt <= cutoff { continue }

            events.append(ActivityEvent(
                id: "session-created-\(sid.uuidString)",
                sessionId: sid.uuidString,
                sessionName: session.name,
                projectName: session.project?.name,
                eventType: .systemEvent,
                title: "Session started",
                detail: nil,
                timestamp: createdAt,
                severity: .info
            ))
        }

        // --- Message events ---
        // Load the 200 most-recent messages, then filter in memory (avoids Fluent
        // timestamp-filter edge cases with nullable @Timestamp properties).
        let messages = try await MessageModel.query(on: req.db)
            .sort(\.$createdAt, .descending)
            .limit(200)
            .all()

        for message in messages {
            guard let msgId = message.id,
                  let createdAt = message.createdAt else { continue }

            // Respect the since cursor
            if let cutoff = since, createdAt <= cutoff { continue }

            let msgSessionId = message.$session.id

            // Only include messages from sessions in scope
            guard targetSessionIds.contains(msgSessionId) else { continue }

            let info = sessionLookup[msgSessionId]
            let (eventType, severity) = classify(message)
            let title = makeTitle(eventType: eventType, content: message.content)
            let detail: String? = message.content.isEmpty
                ? nil
                : String(message.content.prefix(300))

            events.append(ActivityEvent(
                id: msgId.uuidString,
                sessionId: msgSessionId.uuidString,
                sessionName: info?.name ?? nil,
                projectName: info?.projectName ?? nil,
                eventType: eventType,
                title: title,
                detail: detail,
                timestamp: createdAt,
                severity: severity,
                messageId: msgId.uuidString
            ))
        }

        // Newest first
        events.sort { $0.timestamp > $1.timestamp }
        return events
    }

    /// Infer `ActivityEventType` and `ActivityEventSeverity` from a message row.
    private func classify(_ message: MessageModel) -> (ActivityEventType, ActivityEventSeverity) {
        // Check tool calls for permission requests
        if let toolCalls = message.toolCalls, !toolCalls.isEmpty,
           toolCalls.contains("permission") {
            return (.permissionRequest, .warning)
        }

        let role = MessageRole(rawValue: message.role) ?? .user

        if role == .system {
            return (.systemEvent, .info)
        }

        // Error detection via content keywords
        let lower = message.content.lowercased()
        if lower.hasPrefix("error") || lower.contains("failed:") || lower.contains("exception:") {
            return (.error, .error)
        }

        if role == .assistant {
            let isCompletion = lower.contains("task completed")
                || lower.contains("all done")
                || lower.contains("i've completed")
            return isCompletion ? (.completion, .info) : (.messageReceived, .info)
        }

        return (.messageSent, .info)
    }

    /// Build a short display title for an event.
    private func makeTitle(eventType: ActivityEventType, content: String) -> String {
        switch eventType {
        case .messageSent, .messageReceived, .error:
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                switch eventType {
                case .messageSent: return "Message sent"
                case .error: return "Error occurred"
                default: return "Response received"
                }
            }
            return trimmed.count > 80 ? String(trimmed.prefix(80)) + "…" : trimmed
        case .permissionRequest:
            return "Permission request"
        case .completion:
            return "Task completed"
        case .fileChange:
            return "File changed"
        case .systemEvent:
            return "Session started"
        }
    }

    /// Parse an ISO 8601 date string, accepting both fractional-seconds and basic formats.
    private func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
