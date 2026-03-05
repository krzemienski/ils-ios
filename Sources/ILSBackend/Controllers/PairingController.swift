import Vapor
import ILSShared

/// Controller for QR code pairing endpoints.
///
/// Routes (all under `/api/v1/pairing`):
/// - `GET  /pairing/qr`        — generate a new pairing token, return QRPairingTokenResponse
/// - `DELETE /pairing/qr/:token` — invalidate a pairing token
struct PairingController: RouteCollection {
    let pairingService = PairingService.shared

    func boot(routes: RoutesBuilder) throws {
        let pairing = routes.grouped("pairing")

        pairing.get("qr", use: self.generateQR)
        pairing.delete("qr", ":token", use: self.invalidateQR)
    }

    // MARK: - Endpoints

    /// GET /pairing/qr — generate a new QR pairing token.
    ///
    /// Returns a `QRPairingTokenResponse` whose `qrData` field is the
    /// JSON-encoded `QRPairingPayload` string ready to be rendered as a QR code.
    @Sendable
    func generateQR(req: Request) async throws -> Response {
        do {
            let response = try await pairingService.generateToken()
            return try encodeResponse(response, status: .ok)
        } catch {
            throw Abort(.internalServerError, reason: "Failed to generate pairing token: \(error)")
        }
    }

    /// DELETE /pairing/qr/:token — invalidate a pairing token.
    ///
    /// Accepts a token UUID in the URL path and removes it from the active
    /// token store. Safe to call even if the token has already expired.
    @Sendable
    func invalidateQR(req: Request) async throws -> Response {
        guard let token = req.parameters.get("token") else {
            throw Abort(.badRequest, reason: "Missing token parameter")
        }
        await pairingService.invalidateToken(token)
        let body: [String: Bool] = ["invalidated": true]
        return try encodeResponse(body, status: .ok)
    }

    // MARK: - Helpers

    private func encodeResponse<T: Encodable>(_ value: T, status: HTTPResponseStatus) throws -> Response {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        return Response(
            status: status,
            headers: ["Content-Type": "application/json"],
            body: .init(data: data)
        )
    }
}

// MARK: - Vapor Content Conformance

extension QRPairingTokenResponse: Content {}
