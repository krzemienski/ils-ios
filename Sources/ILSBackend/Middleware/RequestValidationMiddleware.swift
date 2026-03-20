import Vapor

/// Request validation middleware that enforces Content-Type headers, validates JSON bodies,
/// and rejects requests with suspicious headers or oversized query strings.
///
/// Behavior:
/// - POST, PUT, and PATCH requests must include `Content-Type: application/json`.
/// - Request bodies on mutating methods are validated as parseable JSON.
/// - Requests with oversized query strings (>2048 chars) are rejected.
/// - Requests with suspicious headers (e.g., proxy injection) are rejected.
/// - Health endpoints are exempt from validation.
/// - Returns structured JSON errors consistent with ILSErrorMiddleware patterns.
struct RequestValidationMiddleware: AsyncMiddleware {
    /// Maximum allowed query string length in characters.
    private let maxQueryStringLength: Int

    init(maxQueryStringLength: Int = 2048) {
        self.maxQueryStringLength = maxQueryStringLength
    }

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Health endpoints are always exempt
        if request.url.path.hasPrefix("/health") {
            return try await next.respond(to: request)
        }

        // Validate query string length
        if let query = request.url.query, query.count > maxQueryStringLength {
            throw Abort(.badRequest, reason: "Query string exceeds maximum allowed length of \(maxQueryStringLength) characters.")
        }

        // Check for suspicious headers
        if let reason = detectSuspiciousHeaders(request) {
            request.logger.warning("Rejected request with suspicious header: \(reason) from \(request.remoteAddress?.description ?? "unknown")")
            throw Abort(.badRequest, reason: reason)
        }

        // Content-Type validation for mutating methods
        let mutatingMethods: [HTTPMethod] = [.POST, .PUT, .PATCH]
        if mutatingMethods.contains(request.method) {
            try validateContentType(request)
            try validateJSONBody(request)
        }

        return try await next.respond(to: request)
    }

    /// Validates that mutating requests include `application/json` Content-Type.
    private func validateContentType(_ request: Request) throws {
        // Allow requests with no body (Content-Length: 0 or missing body)
        if let contentLength = request.headers.first(name: .contentLength),
           contentLength == "0" {
            return
        }

        // If there's a body, Content-Type must be application/json
        guard let contentType = request.headers.contentType else {
            // Only require Content-Type if there appears to be a body
            if request.body.data != nil {
                throw Abort(.unsupportedMediaType, reason: "Content-Type header is required. Use 'application/json'.")
            }
            return
        }

        guard contentType == .json || contentType == .jsonAPI else {
            throw Abort(.unsupportedMediaType, reason: "Unsupported Content-Type '\(contentType.serialize())'. Use 'application/json'.")
        }
    }

    /// Validates that the request body is parseable JSON.
    private func validateJSONBody(_ request: Request) throws {
        guard let body = request.body.data, body.readableBytes > 0 else {
            return
        }

        // Attempt to parse the body as JSON
        let bytes = body.getBytes(at: body.readerIndex, length: body.readableBytes) ?? []
        do {
            _ = try JSONSerialization.jsonObject(with: Data(bytes), options: [])
        } catch {
            throw Abort(.badRequest, reason: "Request body is not valid JSON.")
        }
    }

    /// Detects suspicious or potentially malicious headers.
    ///
    /// Returns a reason string if suspicious headers are found, nil otherwise.
    private func detectSuspiciousHeaders(_ request: Request) -> String? {
        // Reject proxy-injection headers that shouldn't come from legitimate clients
        let suspiciousHeaders: [String] = [
            "X-Forwarded-Server",
            "X-Original-URL",
            "X-Rewrite-URL"
        ]

        for header in suspiciousHeaders {
            if request.headers.first(name: header) != nil {
                return "Unexpected header '\(header)' is not allowed."
            }
        }

        // Reject if Host header contains suspicious characters (null bytes, newlines)
        if let host = request.headers.first(name: .host) {
            if host.contains("\0") || host.contains("\r") || host.contains("\n") {
                return "Invalid characters in Host header."
            }
        }

        return nil
    }
}
