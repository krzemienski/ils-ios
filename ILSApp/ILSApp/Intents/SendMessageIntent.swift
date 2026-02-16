import AppIntents
import Foundation

/// Sends a message to an existing Claude Code session via the ILS backend.
///
/// This intent posts a chat stream request and returns the initial acknowledgement.
/// The actual response streams asynchronously via SSE in the app.
@available(iOS 16.0, *)
struct SendMessageIntent: AppIntent {
    static var title: LocalizedStringResource = "Send Message to Session"
    static var description = IntentDescription("Send a message to a Claude Code session via ILS")

    @Parameter(title: "Session")
    var session: SessionEntity

    @Parameter(title: "Message")
    var message: String

    static var parameterSummary: some ParameterSummary {
        Summary("Send \(\.$message) to \(\.$session)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let baseURL = UserDefaults.standard.string(forKey: "serverURL") ?? "http://localhost:9999"
        guard let url = URL(string: "\(baseURL)/api/v1/chat/stream") else {
            return .result(value: "Error: Invalid server URL")
        }

        // Build the chat stream request body
        let body: [String: Any] = [
            "prompt": message,
            "sessionId": session.id
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            return .result(value: "Error: Failed to encode request")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = jsonData
        request.timeoutInterval = 30

        // Apply API key if available
        if let apiKey = loadAPIKey(), !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .result(value: "Error: Invalid response from server")
            }

            if (200...299).contains(httpResponse.statusCode) {
                return .result(value: "Message sent to \(session.name)")
            } else {
                return .result(value: "Error: Server returned status \(httpResponse.statusCode)")
            }
        } catch {
            return .result(value: "Error: \(error.localizedDescription)")
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
