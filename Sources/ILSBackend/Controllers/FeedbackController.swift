import Vapor
import Fluent
import ILSShared
import Foundation

/// Feedback controller providing endpoints for submitting AI response ratings,
/// querying quality trends, surfacing best-rated responses, and exporting data.
struct FeedbackController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let feedback = routes.grouped("feedback")
        feedback.post(use: self.submitFeedback)
        feedback.get("quality", use: self.qualityTrend)
        feedback.get("best", use: self.bestOf)
        feedback.get("export", use: self.exportData)
    }

    // MARK: - Route Handlers

    /// POST /feedback
    ///
    /// Accepts a `SubmitFeedbackRequest` payload, persists a new
    /// `ResponseFeedbackModel` record, and returns the saved entry as a
    /// `FeedbackResponse`.
    @Sendable
    func submitFeedback(req: Request) async throws -> APIResponse<FeedbackResponse> {
        let body = try req.content.decode(SubmitFeedbackRequest.self)

        let rating: FeedbackRating = body.rating >= 1 ? .thumbsUp : .thumbsDown

        let messageId = UUID(uuidString: body.messageId)
        let sessionId = UUID(uuidString: body.sessionId) ?? UUID()
        let projectId = UUID(uuidString: body.projectId)

        let model = ResponseFeedbackModel(
            messageId: messageId,
            sessionId: sessionId,
            projectId: projectId,
            rating: rating,
            comment: body.comment,
            model: body.model.isEmpty ? nil : body.model,
            messageContent: body.messageContent
        )
        try await model.save(on: req.db)

        let response = FeedbackResponse(
            id: model.id?.uuidString ?? UUID().uuidString,
            rating: body.rating,
            comment: model.comment,
            messageId: model.messageId?.uuidString ?? body.messageId,
            sessionId: model.sessionId.uuidString,
            projectId: model.projectId?.uuidString ?? body.projectId,
            model: model.model ?? body.model,
            createdAt: Self.exportFormatter.string(from: model.createdAt ?? Date())
        )
        return APIResponse(success: true, data: response)
    }

    /// GET /feedback/quality?period=week|month
    ///
    /// Returns daily thumbsUp / thumbsDown counts and a quality score (0.0–1.0)
    /// for each day in the requested period. Missing days are filled with zeros.
    @Sendable
    func qualityTrend(req: Request) async throws -> APIResponse<QualityTrendResponse> {
        let (start, end, days) = periodDates(from: req)

        let records = try await ResponseFeedbackModel.query(on: req.db)
            .filter(\.$createdAt >= start)
            .filter(\.$createdAt <= end)
            .all()

        // Pre-populate all days in range with zero values
        var dayMap: [String: (thumbsUp: Int, thumbsDown: Int)] = [:]
        for offset in 0..<days {
            if let day = Calendar.current.date(byAdding: .day, value: offset, to: start) {
                let key = Self.dayFormatter.string(from: day)
                dayMap[key] = (0, 0)
            }
        }

        for record in records {
            let date = record.createdAt ?? Date()
            let key = Self.dayFormatter.string(from: date)
            var current = dayMap[key] ?? (0, 0)
            if record.rating == FeedbackRating.thumbsUp.rawValue {
                current.thumbsUp += 1
            } else {
                current.thumbsDown += 1
            }
            dayMap[key] = current
        }

        let dataPoints = dayMap.keys.sorted().map { key -> QualityTrendPoint in
            let counts = dayMap[key] ?? (0, 0)
            let total = counts.thumbsUp + counts.thumbsDown
            let score = total > 0 ? Double(counts.thumbsUp) / Double(total) : 0.0
            return QualityTrendPoint(
                date: key,
                thumbsUp: counts.thumbsUp,
                thumbsDown: counts.thumbsDown,
                score: score
            )
        }

        return APIResponse(
            success: true,
            data: QualityTrendResponse(
                projectId: "all",
                dataPoints: dataPoints,
                startDate: Self.dayFormatter.string(from: start),
                endDate: Self.dayFormatter.string(from: end)
            )
        )
    }

    /// GET /feedback/best?limit=20
    ///
    /// Returns thumbs-up feedback records ordered descending by creation date,
    /// up to the given limit (default 20).
    @Sendable
    func bestOf(req: Request) async throws -> APIResponse<[BestOfItem]> {
        let limit = (req.query[Int.self, at: "limit"] ?? 20).clamped(to: 1...200)

        let records = try await ResponseFeedbackModel.query(on: req.db)
            .filter(\.$rating == FeedbackRating.thumbsUp.rawValue)
            .sort(\.$createdAt, .descending)
            .limit(limit)
            .all()

        let items = records.map { record -> BestOfItem in
            BestOfItem(
                messageContent: record.messageContent ?? "",
                sessionId: record.sessionId.uuidString,
                rating: 1,
                comment: record.comment,
                model: record.model ?? "",
                timestamp: Self.exportFormatter.string(from: record.createdAt ?? Date()),
                messageId: record.messageId?.uuidString ?? ""
            )
        }

        return APIResponse(success: true, data: items)
    }

    /// GET /feedback/export
    ///
    /// Returns a full dump of all feedback records alongside quality trend
    /// (last 30 days) and top thumbs-up entries.
    @Sendable
    func exportData(req: Request) async throws -> APIResponse<FeedbackExportData> {
        let allRecords = try await ResponseFeedbackModel.query(on: req.db)
            .sort(\.$createdAt, .descending)
            .all()

        let feedbackRecords = allRecords.map { record -> FeedbackResponse in
            FeedbackResponse(
                id: record.id?.uuidString ?? UUID().uuidString,
                rating: record.rating == FeedbackRating.thumbsUp.rawValue ? 1 : -1,
                comment: record.comment,
                messageId: record.messageId?.uuidString ?? "",
                sessionId: record.sessionId.uuidString,
                projectId: record.projectId?.uuidString ?? "",
                model: record.model ?? "",
                createdAt: Self.exportFormatter.string(from: record.createdAt ?? Date())
            )
        }

        // Build a 30-day quality trend for the export
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -30, to: end) ?? end
        let days = 30
        var dayMap: [String: (thumbsUp: Int, thumbsDown: Int)] = [:]
        for offset in 0..<days {
            if let day = Calendar.current.date(byAdding: .day, value: offset, to: start) {
                let key = Self.dayFormatter.string(from: day)
                dayMap[key] = (0, 0)
            }
        }
        for record in allRecords {
            let date = record.createdAt ?? Date()
            guard date >= start else { continue }
            let key = Self.dayFormatter.string(from: date)
            var current = dayMap[key] ?? (0, 0)
            if record.rating == FeedbackRating.thumbsUp.rawValue {
                current.thumbsUp += 1
            } else {
                current.thumbsDown += 1
            }
            dayMap[key] = current
        }
        let qualityTrend = dayMap.keys.sorted().map { key -> QualityTrendPoint in
            let counts = dayMap[key] ?? (0, 0)
            let total = counts.thumbsUp + counts.thumbsDown
            let score = total > 0 ? Double(counts.thumbsUp) / Double(total) : 0.0
            return QualityTrendPoint(
                date: key,
                thumbsUp: counts.thumbsUp,
                thumbsDown: counts.thumbsDown,
                score: score
            )
        }

        let bestOf = allRecords
            .filter { $0.rating == FeedbackRating.thumbsUp.rawValue }
            .prefix(20)
            .map { record -> BestOfItem in
                BestOfItem(
                    messageContent: record.messageContent ?? "",
                    sessionId: record.sessionId.uuidString,
                    rating: 1,
                    comment: record.comment,
                    model: record.model ?? "",
                    timestamp: Self.exportFormatter.string(from: record.createdAt ?? Date()),
                    messageId: record.messageId?.uuidString ?? ""
                )
            }

        let exportedAt = Self.exportFormatter.string(from: Date())

        return APIResponse(
            success: true,
            data: FeedbackExportData(
                projectId: "all",
                exportedAt: exportedAt,
                feedbackRecords: feedbackRecords,
                qualityTrend: qualityTrend,
                bestOf: Array(bestOf)
            )
        )
    }

    // MARK: - Private Helpers

    /// Date formatters (static to avoid repeated allocation).
    private static let dayFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()

    private static let exportFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Resolves the `period` query parameter to (startDate, endDate, dayCount).
    /// Defaults to `week` (7 days). `month` yields 30 days.
    private func periodDates(from req: Request) -> (start: Date, end: Date, days: Int) {
        let periodStr = req.query[String.self, at: "period"] ?? "week"
        let days = periodStr == "month" ? 30 : 7
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end) ?? end
        return (start, end, days)
    }
}

// MARK: - Comparable clamped helper

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
