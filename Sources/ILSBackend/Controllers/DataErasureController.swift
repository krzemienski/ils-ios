import Vapor
import Fluent
import ILSShared

/// GDPR Article 17 "Right to Erasure" controller.
///
/// Provides a single endpoint that deletes all user data in a database
/// transaction. Deletion order respects foreign key constraints:
/// messages (FK -> sessions) are deleted before sessions.
///
/// Registered on the admin-protected route group in `routes.swift`.
struct DataErasureController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let data = routes.grouped("data")
        data.delete("all", use: deleteAllData)
    }

    /// Deletes all user data across all tables in a single transaction.
    ///
    /// - Returns: `APIResponse<DataErasureResponse>` with per-table deletion counts.
    @Sendable
    func deleteAllData(req: Request) async throws -> Response {
        let counts = try await req.db.transaction { db -> DataErasureResponse in
            var c = DataErasureResponse()

            // Delete in FK-safe order: children before parents
            // 1. Messages (FK -> sessions.id)
            c.messagesDeleted = try await MessageModel.query(on: db).count()
            try await MessageModel.query(on: db).delete()

            // 2. Sessions (parent of messages)
            c.sessionsDeleted = try await SessionModel.query(on: db).count()
            try await SessionModel.query(on: db).delete()

            // 3. Projects (no FK dependencies)
            c.projectsDeleted = try await ProjectModel.query(on: db).count()
            try await ProjectModel.query(on: db).delete()

            // 4. Themes (no FK dependencies)
            c.themesDeleted = try await ThemeModel.query(on: db).count()
            try await ThemeModel.query(on: db).delete()

            // 5. Host profiles (no FK dependencies)
            c.fleetHostsDeleted = try await HostProfileModel.query(on: db).count()
            try await HostProfileModel.query(on: db).delete()

            // 6. Cached results (no FK dependencies)
            c.cacheEntriesDeleted = try await CachedResult.query(on: db).count()
            try await CachedResult.query(on: db).delete()

            return c
        }

        req.logger.info("GDPR data erasure complete: \(counts.messagesDeleted) messages, \(counts.sessionsDeleted) sessions, \(counts.projectsDeleted) projects, \(counts.themesDeleted) themes, \(counts.fleetHostsDeleted) host profiles, \(counts.cacheEntriesDeleted) cache entries deleted")

        let body = APIResponse(success: true, data: counts)
        let response = Response(status: .ok)
        try response.content.encode(body)
        response.headers.contentType = .json
        return response
    }
}
