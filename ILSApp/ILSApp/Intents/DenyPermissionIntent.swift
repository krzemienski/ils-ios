import AppIntents
import Foundation

/// Denies the current pending permission request in the active Claude Code session.
///
/// This intent posts a permission denial to the most recent session that has a pending
/// permission request. Useful for hands-free denial via Siri or Shortcuts.
@available(iOS 16.0, *)
struct DenyPermissionIntent: AppIntent {
    static let title: LocalizedStringResource = "Deny Permission"
    static let description = IntentDescription("Deny the pending permission request in ILS")

    @Parameter(title: "Session")
    var session: SessionEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Deny permission in \(\.$session)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let baseURL = UserDefaults.standard.string(forKey: AppConstants.serverURLKey) ?? AppConstants.defaultServerURL

        // Determine which session to use — explicit parameter or most recent active session
        let sessionId: String
        if let explicit = session {
            sessionId = explicit.id
        } else {
            guard let resolved = try await resolveActiveSession(baseURL: baseURL) else {
                return .result(value: "No active session with a pending permission found")
            }
            sessionId = resolved
        }

        guard let url = URL(string: "\(baseURL)/api/v1/sessions/\(sessionId)/permissions/respond") else {
            return .result(value: "Error: Invalid server URL")
        }

        let body = PermissionResponseBody(decision: "deny")
        let jsonData: Data
        do {
            jsonData = try JSONEncoder().encode(body)
        } catch {
            return .result(value: "Error: Failed to encode request — \(error.localizedDescription)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = jsonData
        request.timeoutInterval = 15

        if let apiKey = loadAPIKey(), !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (_, response) = try await IntentURLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .result(value: "Error: Invalid response from server")
            }

            if (200...299).contains(httpResponse.statusCode) {
                return .result(value: "Permission denied")
            } else if httpResponse.statusCode == 404 {
                return .result(value: "No pending permission request found")
            } else {
                return .result(value: "Error: Server returned status \(httpResponse.statusCode)")
            }
        } catch {
            return .result(value: "Error: \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    private struct PermissionResponseBody: Encodable {
        let decision: String
    }

    private func resolveActiveSession(baseURL: String) async throws -> String? {
        guard let url = URL(string: "\(baseURL)/api/v1/sessions?page=1&limit=5") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        if let apiKey = loadAPIKey(), !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await IntentURLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            return nil
        }

        let decoded = try JSONDecoder().decode(ResolveSessionsResponse.self, from: data)
        return decoded.data?.items.first?.id
    }

    private struct ResolveSessionsResponse: Decodable {
        let success: Bool
        let data: PaginatedItems?

        struct PaginatedItems: Decodable {
            let items: [SessionItem]
        }

        struct SessionItem: Decodable {
            let id: String
        }
    }

    private func loadAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "ils_api_key",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
