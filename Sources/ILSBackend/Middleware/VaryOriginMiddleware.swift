import Vapor

/// SEC-CORS-03: Adds `Vary: Origin` header to all responses to prevent cache poisoning.
///
/// When CORS responses are cached by proxies/CDNs, the `Vary: Origin` header ensures
/// that cached responses are not served to requests from different origins.
/// This middleware appends "Origin" to any existing Vary header value.
struct VaryOriginMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let response = try await next.respond(to: request)

        // Append Origin to existing Vary header, or set it if not present
        if let existing = response.headers.first(name: .vary) {
            let values = existing.lowercased().split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if !values.contains("origin") {
                response.headers.replaceOrAdd(name: .vary, value: existing + ", Origin")
            }
        } else {
            response.headers.replaceOrAdd(name: .vary, value: "Origin")
        }

        return response
    }
}
