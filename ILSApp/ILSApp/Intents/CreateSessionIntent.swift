import AppIntents
import Foundation

/// Creates a new Claude Code session via the ILS backend.
@available(iOS 16.0, *)
struct CreateSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Create New Session"
    static var description = IntentDescription("Create a new Claude Code session in ILS")

    @Parameter(title: "Name", default: "New Session")
    var name: String

    @Parameter(title: "Model", default: .sonnet)
    var model: SessionModel

    static var parameterSummary: some ParameterSummary {
        Summary("Create session \(\.$name) with \(\.$model)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let baseURL = UserDefaults.standard.string(forKey: "serverURL") ?? "http://localhost:9999"
        guard let url = URL(string: "\(baseURL)/api/v1/sessions") else {
            return .result(value: "Error: Invalid server URL")
        }

        let body: [String: String] = [
            "name": name,
            "model": model.rawValue
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            return .result(value: "Error: Failed to encode request")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = jsonData
        request.timeoutInterval = 15

        // Apply API key if available
        if let apiKey = loadAPIKey(), !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .result(value: "Error: Invalid response from server")
            }

            if (200...299).contains(httpResponse.statusCode) {
                // Try to extract the session ID from the response
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let sessionData = json["data"] as? [String: Any],
                   let sessionId = sessionData["id"] as? String {
                    return .result(value: "Created session \"\(name)\" (ID: \(sessionId.prefix(8))...)")
                }
                return .result(value: "Created session: \(name)")
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

// MARK: - Session Model Enum

@available(iOS 16.0, *)
enum SessionModel: String, AppEnum {
    case sonnet
    case opus
    case haiku

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Model")
    static var caseDisplayRepresentations: [SessionModel: DisplayRepresentation] = [
        .sonnet: "Sonnet",
        .opus: "Opus",
        .haiku: "Haiku"
    ]
}
