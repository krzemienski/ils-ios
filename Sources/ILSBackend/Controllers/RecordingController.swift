import Vapor
import Fluent
import ILSShared

/// Controller for session recording management and time-lapse playback.
///
/// Routes:
/// - `POST /sessions/:id/recordings`: Start a new recording for a session
/// - `GET /sessions/:id/recordings`: List all recordings for a session
/// - `GET /recordings/:recordingId`: Get a single recording by ID
/// - `PATCH /recordings/:recordingId/stop`: Stop an active recording
/// - `DELETE /recordings/:recordingId`: Delete a recording
/// - `GET /recordings/:recordingId/events`: Fetch playback events derived from session messages
/// - `GET /recordings/:recordingId/export?format=json&redact=false`: Export recording
struct RecordingController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        // Session-scoped recording routes
        let sessionRecordings = routes.grouped("sessions", ":id", "recordings")
        sessionRecordings.post(use: create)
        sessionRecordings.get(use: list)

        // Recording-scoped routes
        let recordings = routes.grouped("recordings")
        recordings.get(":recordingId", use: get)
        recordings.patch(":recordingId", "stop", use: stop)
        recordings.delete(":recordingId", use: deleteRecording)
        recordings.get(":recordingId", "events", use: playbackEvents)
        recordings.get(":recordingId", "export", use: exportRecording)
    }

    // MARK: - Create Recording

    /// POST /sessions/:id/recordings
    ///
    /// Starts a new recording for the given session with status=recording.
    ///
    /// Optional JSON body:
    /// - `name`: Human-readable name for the recording
    @Sendable
    func create(req: Request) async throws -> APIResponse<SessionRecording> {
        guard let sessionId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }

        guard let session = try await SessionModel.query(on: req.db)
            .with(\.$project)
            .filter(\.$id == sessionId)
            .first()
        else {
            throw Abort(.notFound, reason: "Session not found")
        }

        // Decode optional name from request body
        let body = try? req.content.decode(CreateRecordingBody.self)

        let recording = SessionRecordingModel(
            sessionId: sessionId,
            name: body?.name,
            status: .recording,
            eventCount: 0
        )
        try await recording.save(on: req.db)

        return APIResponse(
            success: true,
            data: recording.toShared(
                sessionName: session.name,
                projectName: session.project?.name
            )
        )
    }

    // MARK: - List Recordings

    /// GET /sessions/:id/recordings
    ///
    /// Returns all recordings for the given session, newest first.
    @Sendable
    func list(req: Request) async throws -> APIResponse<RecordingListResponse> {
        guard let sessionId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }

        guard let session = try await SessionModel.query(on: req.db)
            .with(\.$project)
            .filter(\.$id == sessionId)
            .first()
        else {
            throw Abort(.notFound, reason: "Session not found")
        }

        let recordings = try await SessionRecordingModel.query(on: req.db)
            .filter(\.$session.$id == sessionId)
            .sort(\.$startedAt, .descending)
            .all()

        let shared = recordings.map {
            $0.toShared(
                sessionName: session.name,
                projectName: session.project?.name
            )
        }

        return APIResponse(
            success: true,
            data: RecordingListResponse(
                recordings: shared,
                totalCount: shared.count,
                hasMore: false
            )
        )
    }

    // MARK: - Get Recording

    /// GET /recordings/:recordingId
    ///
    /// Returns a single recording by ID.
    @Sendable
    func get(req: Request) async throws -> APIResponse<SessionRecording> {
        let recording = try await fetchRecording(req: req)

        let session = try await SessionModel.query(on: req.db)
            .with(\.$project)
            .filter(\.$id == recording.$session.id)
            .first()

        return APIResponse(
            success: true,
            data: recording.toShared(
                sessionName: session?.name,
                projectName: session?.project?.name
            )
        )
    }

    // MARK: - Stop Recording

    /// PATCH /recordings/:recordingId/stop
    ///
    /// Stops an active recording by setting status=stopped and stoppedAt=now.
    @Sendable
    func stop(req: Request) async throws -> APIResponse<SessionRecording> {
        let recording = try await fetchRecording(req: req)

        recording.status = RecordingStatus.stopped.rawValue
        recording.stoppedAt = Date()
        try await recording.save(on: req.db)

        let session = try await SessionModel.query(on: req.db)
            .with(\.$project)
            .filter(\.$id == recording.$session.id)
            .first()

        return APIResponse(
            success: true,
            data: recording.toShared(
                sessionName: session?.name,
                projectName: session?.project?.name
            )
        )
    }

    // MARK: - Delete Recording

    /// DELETE /recordings/:recordingId
    ///
    /// Permanently deletes a recording.
    @Sendable
    func deleteRecording(req: Request) async throws -> HTTPStatus {
        let recording = try await fetchRecording(req: req)
        try await recording.delete(on: req.db)
        return .noContent
    }

    // MARK: - Playback Events

    /// GET /recordings/:recordingId/events
    ///
    /// Derives playback events from session messages within the recording time window.
    /// Events are ordered chronologically with offset seconds from the recording start.
    /// Key moments (permission requests, errors, completions) are flagged with `isKeyMoment`.
    ///
    /// Returns `RecordingEventsResponse` with the recording metadata and ordered event list.
    @Sendable
    func playbackEvents(req: Request) async throws -> APIResponse<RecordingEventsResponse> {
        let recording = try await fetchRecording(req: req)

        guard let recordingId = recording.id else {
            throw Abort(.internalServerError, reason: "Recording has no ID")
        }

        let session = try await SessionModel.query(on: req.db)
            .with(\.$project)
            .filter(\.$id == recording.$session.id)
            .first()

        let startedAt = recording.startedAt ?? Date()
        let stoppedAt = recording.stoppedAt

        let allMessages = try await MessageModel.query(on: req.db)
            .filter(\.$session.$id == recording.$session.id)
            .sort(\.$createdAt, .ascending)
            .all()

        var events: [RecordingEvent] = []

        for message in allMessages {
            guard let msgId = message.id,
                  let createdAt = message.createdAt else { continue }

            // Only include messages within the recording time window
            if createdAt < startedAt { continue }
            if let end = stoppedAt, createdAt > end { continue }

            let (eventType, isKeyMoment) = classifyMessage(message)
            let title = makeTitle(eventType: eventType, content: message.content)
            let detail: String? = message.content.isEmpty
                ? nil
                : String(message.content.prefix(300))
            let offsetSeconds = createdAt.timeIntervalSince(startedAt)

            events.append(RecordingEvent(
                id: "msg-\(msgId.uuidString)",
                recordingId: recordingId.uuidString,
                eventType: eventType,
                offsetSeconds: max(offsetSeconds, 0),
                timestamp: createdAt,
                title: title,
                detail: detail,
                metadata: nil,
                isKeyMoment: isKeyMoment
            ))
        }

        // Keep event count in sync
        if recording.eventCount != events.count {
            recording.eventCount = events.count
            try await recording.save(on: req.db)
        }

        let sharedRecording = recording.toShared(
            sessionName: session?.name,
            projectName: session?.project?.name
        )

        return APIResponse(
            success: true,
            data: RecordingEventsResponse(
                recording: sharedRecording,
                events: events
            )
        )
    }

    // MARK: - Export

    /// GET /recordings/:recordingId/export
    ///
    /// Exports the recording in JSON or Markdown format.
    ///
    /// Query parameters:
    /// - `format`: `json` (default) or `markdown`
    /// - `redact`: `true` to strip message content from detail fields for privacy
    @Sendable
    func exportRecording(req: Request) async throws -> Response {
        let recording = try await fetchRecording(req: req)

        guard let recordingId = recording.id else {
            throw Abort(.internalServerError, reason: "Recording has no ID")
        }

        let session = try await SessionModel.query(on: req.db)
            .with(\.$project)
            .filter(\.$id == recording.$session.id)
            .first()

        let formatString: String = req.query["format"] ?? "json"
        let redact: Bool = (req.query["redact"] as String?) == "true"

        let startedAt = recording.startedAt ?? Date()
        let stoppedAt = recording.stoppedAt

        let allMessages = try await MessageModel.query(on: req.db)
            .filter(\.$session.$id == recording.$session.id)
            .sort(\.$createdAt, .ascending)
            .all()

        var events: [RecordingEvent] = []

        for message in allMessages {
            guard let msgId = message.id,
                  let createdAt = message.createdAt else { continue }

            if createdAt < startedAt { continue }
            if let end = stoppedAt, createdAt > end { continue }

            let (eventType, isKeyMoment) = classifyMessage(message)
            let rawTitle = makeTitle(eventType: eventType, content: message.content)
            let rawDetail: String? = message.content.isEmpty
                ? nil
                : String(message.content.prefix(300))
            let offsetSeconds = createdAt.timeIntervalSince(startedAt)

            events.append(RecordingEvent(
                id: "msg-\(msgId.uuidString)",
                recordingId: recordingId.uuidString,
                eventType: eventType,
                offsetSeconds: max(offsetSeconds, 0),
                timestamp: createdAt,
                title: redact ? eventType.rawValue : rawTitle,
                detail: redact ? nil : rawDetail,
                metadata: nil,
                isKeyMoment: isKeyMoment
            ))
        }

        let sharedRecording = recording.toShared(
            sessionName: session?.name,
            projectName: session?.project?.name
        )
        let eventsResponse = RecordingEventsResponse(recording: sharedRecording, events: events)

        if formatString == "markdown" {
            let markdown = buildMarkdown(eventsResponse: eventsResponse, redacted: redact)
            return Response(
                status: .ok,
                headers: HTTPHeaders([("Content-Type", "text/markdown; charset=utf-8")]),
                body: .init(string: markdown)
            )
        } else {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(eventsResponse)
            return Response(
                status: .ok,
                headers: HTTPHeaders([("Content-Type", "application/json")]),
                body: .init(data: data)
            )
        }
    }

    // MARK: - Private Helpers

    /// Fetch a `SessionRecordingModel` by `:recordingId` parameter, throwing 404 if missing.
    private func fetchRecording(req: Request) async throws -> SessionRecordingModel {
        guard let recordingId = req.parameters.get("recordingId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid recording ID")
        }
        guard let recording = try await SessionRecordingModel.find(recordingId, on: req.db) else {
            throw Abort(.notFound, reason: "Recording not found")
        }
        return recording
    }

    /// Classify a message into a `RecordingEventType` and whether it is a key moment.
    ///
    /// Key moments are permission requests, errors, and task completions — events the user
    /// will want to navigate to directly during playback.
    private func classifyMessage(_ message: MessageModel) -> (RecordingEventType, Bool) {
        // Permission request detected via tool calls content
        if let toolCalls = message.toolCalls, !toolCalls.isEmpty,
           toolCalls.contains("permission") {
            return (.permissionRequest, true)
        }

        let role = MessageRole(rawValue: message.role) ?? .user

        if role == .system {
            return (.systemEvent, false)
        }

        // Error detection via common content prefixes/patterns
        let lower = message.content.lowercased()
        if lower.hasPrefix("error") || lower.contains("failed:") || lower.contains("exception:") {
            return (.error, true)
        }

        if role == .assistant {
            let isCompletion = lower.contains("task completed")
                || lower.contains("all done")
                || lower.contains("i've completed")
            return isCompletion ? (.completion, true) : (.messageReceived, false)
        }

        return (.messageSent, false)
    }

    /// Build a short display title for a recording event.
    private func makeTitle(eventType: RecordingEventType, content: String) -> String {
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
        case .permissionDecision:
            return "Permission decision"
        case .completion:
            return "Task completed"
        case .fileChange:
            return "File changed"
        case .sessionStart:
            return "Session started"
        case .sessionEnd:
            return "Session ended"
        case .systemEvent:
            return "System event"
        }
    }

    /// Render a `RecordingEventsResponse` as a human-readable Markdown document.
    private func buildMarkdown(eventsResponse: RecordingEventsResponse, redacted: Bool) -> String {
        let rec = eventsResponse.recording
        var lines: [String] = []

        lines.append("# Session Recording: \(rec.sessionName ?? "Unnamed Session")")
        lines.append("")

        if let projectName = rec.projectName {
            lines.append("**Project:** \(projectName)")
        }
        lines.append("**Status:** \(rec.status.rawValue)")

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        lines.append("**Started:** \(formatter.string(from: rec.startedAt))")

        if let stopped = rec.stoppedAt {
            lines.append("**Stopped:** \(formatter.string(from: stopped))")
        }
        if let duration = rec.durationSeconds {
            lines.append("**Duration:** \(Int(duration))s")
        }
        lines.append("**Events:** \(eventsResponse.events.count)")

        if redacted {
            lines.append("")
            lines.append("> ⚠️ Content has been redacted for privacy.")
        }

        lines.append("")
        lines.append("## Timeline")
        lines.append("")

        for event in eventsResponse.events {
            let offsetLabel = String(format: "+%.1fs", event.offsetSeconds)
            let keyMark = event.isKeyMoment ? " ⭐" : ""
            lines.append("### \(offsetLabel) — \(event.title)\(keyMark)")
            lines.append("")
            lines.append("- **Type:** `\(event.eventType.rawValue)`")
            if let detail = event.detail {
                lines.append("- **Detail:** \(detail)")
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Request Body

/// Optional request body for creating a recording.
private struct CreateRecordingBody: Content {
    var name: String?
}
