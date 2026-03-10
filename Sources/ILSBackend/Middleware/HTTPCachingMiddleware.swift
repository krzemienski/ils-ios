import Vapor
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

/// Middleware that adds HTTP caching headers (ETag, Cache-Control) to JSON GET responses
/// and handles conditional requests (If-None-Match → 304 Not Modified).
///
/// Only applies to:
/// - GET requests
/// - 2xx responses with JSON content type
/// - Buffered (non-streaming) response bodies
///
/// Skipped for:
/// - Non-GET methods (POST, PUT, DELETE, etc.)
/// - Streaming responses — `response.body.data` is nil for streamed/chunked bodies
///   (covers SSE `text/event-stream`, WebSocket upgrades, chunked chat responses)
struct HTTPCachingMiddleware: AsyncMiddleware {

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Only process GET requests
        guard request.method == .GET else {
            return try await next.respond(to: request)
        }

        var response = try await next.respond(to: request)

        // Skip non-2xx responses
        guard (200...299).contains(response.status.code) else {
            return response
        }

        // Skip if response is not JSON
        guard let contentType = response.headers.contentType,
              contentType.type == "application",
              contentType.subType == "json" else {
            return response
        }

        // Skip streaming responses — .data returns nil for streamed/chunked bodies.
        // This naturally excludes SSE and WebSocket upgrade responses.
        guard let bodyBytes = response.body.data else {
            return response
        }

        // NET-005: ETag generation strategy.
        // Computes a SHA256 hash of the full response body bytes, formatted as a weak
        // ETag (W/"<hex>"). SHA256 provides strong collision resistance — two responses
        // produce the same ETag only if their body bytes are byte-identical.
        // Weak ETag (W/) is appropriate because semantic equivalence may differ despite
        // identical bytes (e.g., different Transfer-Encoding).
        // Use .map — SHA256 digest bytes are never nil, so compactMap is misleading.
        let hash = SHA256.hash(data: bodyBytes)
        let hexString = hash.map { String(format: "%02x", $0) }.joined()
        let etag = "W/\"\(hexString)\""

        // Handle conditional request: return 304 if ETag matches If-None-Match header.
        // Compare the normalized client ETag against hexString directly — our server ETags
        // are always W/"<hex>", so normalizeETag(etag) == hexString by construction,
        // avoiding a redundant normalization call on the server-generated value.
        if let clientETag = request.headers[.ifNoneMatch].first,
           normalizeETag(clientETag) == hexString {
            var notModified = Response(status: .notModified)
            notModified.headers.replaceOrAdd(name: .eTag, value: etag)
            addCacheControl(to: &notModified, path: request.url.path)
            return notModified
        }

        // Add ETag and Cache-Control headers to the full response
        response.headers.replaceOrAdd(name: .eTag, value: etag)
        addCacheControl(to: &response, path: request.url.path)

        return response
    }

    /// Strip W/ prefix and surrounding quotes for ETag comparison.
    private func normalizeETag(_ etag: String) -> String {
        var value = etag.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("W/") {
            value = String(value.dropFirst(2))
        }
        if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
            value = String(value.dropFirst().dropLast())
        }
        return value
    }

    /// Add a Cache-Control header based on the request path prefix.
    ///
    /// TTL rules:
    /// - `/health`                               → no-cache, no-store
    /// - `/api/v1/skills|mcp|plugins|themes`     → private, max-age=3600, must-revalidate (1 hr)
    /// - `/api/v1/config`                        → private, max-age=300, must-revalidate (5 min)
    /// - `/api/v1/projects`                      → private, max-age=60, must-revalidate (1 min)
    /// - `/api/v1/sessions`                      → private, max-age=15, must-revalidate (15 sec)
    /// - default                                 → private, max-age=30
    private func addCacheControl(to response: inout Response, path: String) {
        let directive: String
        if path.hasPrefix("/health") {
            directive = "no-cache, no-store"
        } else if path.hasPrefix("/api/v1/skills") ||
                  path.hasPrefix("/api/v1/mcp") ||
                  path.hasPrefix("/api/v1/plugins") ||
                  path.hasPrefix("/api/v1/themes") {
            directive = "private, max-age=3600, must-revalidate"
        } else if path.hasPrefix("/api/v1/config") {
            directive = "private, max-age=300, must-revalidate"
        } else if path.hasPrefix("/api/v1/projects") {
            directive = "private, max-age=60, must-revalidate"
        } else if path.hasPrefix("/api/v1/sessions") {
            directive = "private, max-age=15, must-revalidate"
        } else {
            directive = "private, max-age=30"
        }
        response.headers.replaceOrAdd(name: .cacheControl, value: directive)
    }
}
