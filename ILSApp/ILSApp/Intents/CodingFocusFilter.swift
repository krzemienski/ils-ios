import AppIntents
import Foundation

/// Focus filter that configures ILS behavior when the Coding focus is active.
/// Users can suppress non-critical notifications and set a focused session context
/// directly from Focus settings on iPhone, iPad, and Mac.
@available(iOS 16.0, macOS 13.0, *)
struct CodingFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "ILS Coding Focus"

    /// Instance-level display representation shown in Focus filter settings.
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "ILS Coding Focus",
            subtitle: suppressNotifications ? "Notifications suppressed" : "Notifications enabled"
        )
    }

    /// When enabled, ILS will suppress non-critical notifications while Coding focus is active.
    @Parameter(title: "Suppress Notifications", default: true)
    var suppressNotifications: Bool

    /// The name used when auto-creating a session for this focus period.
    @Parameter(title: "Focused Session Name", default: "Coding Session")
    var focusedSessionName: String

    /// When enabled, ILS will automatically create a new session when Coding focus activates.
    @Parameter(title: "Auto-create Session on Focus", default: false)
    var autoCreateSession: Bool

    /// Called by the system when the Coding focus is enabled or its settings change.
    /// Persists configuration to UserDefaults so the main app can react accordingly.
    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults.standard
        defaults.set(suppressNotifications, forKey: "ils_focus_suppress_notifications")
        defaults.set(focusedSessionName, forKey: "ils_focus_session_name")
        defaults.set(autoCreateSession, forKey: "ils_focus_auto_create_session")
        defaults.set(true, forKey: "ils_coding_focus_active")

        if autoCreateSession {
            try await createFocusSession(named: focusedSessionName)
        }

        return .result()
    }

    // MARK: - Private Helpers

    /// Creates a new ILS session for the focus period.
    private func createFocusSession(named sessionName: String) async throws {
        let baseURL = UserDefaults.standard.string(forKey: "serverURL") ?? "http://localhost:9999"
        guard let url = URL(string: "\(baseURL)/api/v1/sessions") else { return }

        struct SessionBody: Encodable {
            let name: String
            let model: String
        }

        guard let jsonData = try? JSONEncoder().encode(SessionBody(name: sessionName, model: "sonnet")) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = jsonData
        request.timeoutInterval = 15

        if let apiKey = loadAPIKey(), !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await IntentURLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else { return }

        struct SessionAPIResponse: Decodable {
            let success: Bool
            let data: SessionData?
            struct SessionData: Decodable { let id: String }
        }

        if let decoded = try? JSONDecoder().decode(SessionAPIResponse.self, from: data),
           let sessionId = decoded.data?.id {
            UserDefaults.standard.set(sessionId, forKey: "ils_focus_created_session_id")
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
