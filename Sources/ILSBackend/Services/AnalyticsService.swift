import Vapor
import Fluent
import ILSShared

/// Service for handling analytics event processing and querying
struct AnalyticsService {

    // MARK: - Event Creation

    /// Create and persist an analytics event
    /// - Parameters:
    ///   - request: The incoming CreateAnalyticsEventRequest
    ///   - db: Database instance for persistence
    /// - Returns: The created AnalyticsEventModel with ID and timestamp
    static func createEvent(
        from request: CreateAnalyticsEventRequest,
        on db: Database
    ) async throws -> AnalyticsEventModel {
        let event = AnalyticsEventModel(
            eventName: request.eventName,
            eventData: request.eventData,
            deviceId: request.deviceId,
            userId: request.userId,
            sessionId: request.sessionId
        )

        try await event.save(on: db)

        return event
    }

    // MARK: - Event Querying

    /// Query analytics events with optional filters
    /// - Parameters:
    ///   - eventName: Filter by specific event name (optional)
    ///   - userId: Filter by user ID (optional)
    ///   - sessionId: Filter by session ID (optional)
    ///   - deviceId: Filter by device ID (optional)
    ///   - startDate: Filter events after this date (optional)
    ///   - endDate: Filter events before this date (optional)
    ///   - limit: Maximum number of events to return (default: 100)
    ///   - db: Database instance for querying
    /// - Returns: Array of AnalyticsEventModels matching the criteria
    static func queryEvents(
        eventName: String? = nil,
        userId: UUID? = nil,
        sessionId: UUID? = nil,
        deviceId: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        limit: Int = 100,
        on db: Database
    ) async throws -> [AnalyticsEventModel] {
        var query = AnalyticsEventModel.query(on: db)

        // Apply filters
        if let eventName = eventName {
            query = query.filter(\.$eventName == eventName)
        }

        if let userId = userId {
            query = query.filter(\.$userId == userId)
        }

        if let sessionId = sessionId {
            query = query.filter(\.$sessionId == sessionId)
        }

        if let deviceId = deviceId {
            query = query.filter(\.$deviceId == deviceId)
        }

        if let startDate = startDate {
            query = query.filter(\.$createdAt >= startDate)
        }

        if let endDate = endDate {
            query = query.filter(\.$createdAt <= endDate)
        }

        // Sort by most recent first and apply limit
        return try await query
            .sort(\.$createdAt, .descending)
            .limit(limit)
            .all()
    }

    /// Get event count grouped by event name
    /// - Parameters:
    ///   - startDate: Count events after this date (optional)
    ///   - endDate: Count events before this date (optional)
    ///   - db: Database instance for querying
    /// - Returns: Dictionary mapping event names to counts
    static func getEventCounts(
        startDate: Date? = nil,
        endDate: Date? = nil,
        on db: Database
    ) async throws -> [String: Int] {
        var query = AnalyticsEventModel.query(on: db)

        if let startDate = startDate {
            query = query.filter(\.$createdAt >= startDate)
        }

        if let endDate = endDate {
            query = query.filter(\.$createdAt <= endDate)
        }

        let events = try await query.all()

        // Group by event name and count
        var counts: [String: Int] = [:]
        for event in events {
            counts[event.eventName, default: 0] += 1
        }

        return counts
    }

    /// Get analytics for a specific user
    /// - Parameters:
    ///   - userId: The user ID to get analytics for
    ///   - limit: Maximum number of events to return (default: 100)
    ///   - db: Database instance for querying
    /// - Returns: Array of AnalyticsEventModels for the user
    static func getUserAnalytics(
        userId: UUID,
        limit: Int = 100,
        on db: Database
    ) async throws -> [AnalyticsEventModel] {
        return try await queryEvents(
            userId: userId,
            limit: limit,
            on: db
        )
    }

    /// Get analytics for a specific session
    /// - Parameters:
    ///   - sessionId: The session ID to get analytics for
    ///   - db: Database instance for querying
    /// - Returns: Array of AnalyticsEventModels for the session
    static func getSessionAnalytics(
        sessionId: UUID,
        on db: Database
    ) async throws -> [AnalyticsEventModel] {
        return try await queryEvents(
            sessionId: sessionId,
            limit: 1000, // Higher limit for session-specific queries
            on: db
        )
    }
}
