import Vapor
import Fluent
import ILSShared

struct AnalyticsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let analytics = routes.grouped("analytics")

        analytics.post("events", use: createEvent)
    }

    /// POST /analytics/events - Ingest analytics event
    @Sendable
    func createEvent(req: Request) async throws -> Response {
        let input = try req.content.decode(CreateAnalyticsEventRequest.self)

        // Use AnalyticsService to create and persist event
        let event = try await AnalyticsService.createEvent(
            from: input,
            on: req.db
        )

        // Return 201 Created with event details
        let response = APIResponse(
            success: true,
            data: CreatedResponse(
                id: event.id!,
                createdAt: event.createdAt!
            )
        )

        let jsonResponse = Response(status: .created)
        try jsonResponse.content.encode(response)
        return jsonResponse
    }
}
