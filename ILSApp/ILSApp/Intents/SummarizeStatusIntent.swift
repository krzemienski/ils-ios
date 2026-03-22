import AppIntents
import Foundation

/// Summarizes the current status of all active Claude Code sessions.
///
/// Returns a brief overview of active sessions, their models, message counts,
/// and overall system status. Useful for quick hands-free status checks via Siri.
@available(iOS 16.0, *)
struct SummarizeStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Summarize Status"
    static let description = IntentDescription("Get a summary of active ILS sessions and system status")

    static var parameterSummary: some ParameterSummary {
        Summary("Summarize ILS status")
    }

    /// Codable response for sessions list.
    private struct StatusAPIResponse: Decodable {
        let success: Bool
        let data: PaginatedData?

        struct PaginatedData: Decodable {
            let items: [SessionSummary]
            let total: Int
        }

        struct SessionSummary: Decodable {
            let id: String
            let name: String?
            let model: String
            let messageCount: Int
            let projectName: String?

            private enum CodingKeys: String, CodingKey {
                case id, name, model, messageCount, projectName
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.id = try container.decode(String.self, forKey: .id)
                self.name = try container.decodeIfPresent(String.self, forKey: .name)
                self.model = (try? container.decode(String.self, forKey: .model)) ?? "sonnet"
                self.messageCount = (try? container.decode(Int.self, forKey: .messageCount)) ?? 0
                self.projectName = try container.decodeIfPresent(String.self, forKey: .projectName)
            }
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let baseURL = UserDefaults.standard.string(forKey: AppConstants.serverURLKey) ?? AppConstants.defaultServerURL
        guard let url = URL(string: "\(baseURL)/api/v1/sessions?page=1&limit=10") else {
            return .result(value: "Error: Invalid server URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        if let apiKey = loadAPIKey(), !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await IntentURLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .result(value: "Error: Invalid response from server")
            }

            if (200...299).contains(httpResponse.statusCode) {
                let decoded = try JSONDecoder().decode(StatusAPIResponse.self, from: data)
                return .result(value: formatSummary(decoded))
            } else {
                return .result(value: "Error: Server returned status \(httpResponse.statusCode)")
            }
        } catch {
            return .result(value: "Error: \(error.localizedDescription)")
        }
    }

    private func formatSummary(_ response: StatusAPIResponse) -> String {
        guard let paginatedData = response.data else {
            return "No session data available"
        }

        let sessions = paginatedData.items
        let total = paginatedData.total

        if sessions.isEmpty {
            return "No active sessions. You can create one by saying \"New ILS session\"."
        }

        var lines: [String] = []
        lines.append("\(total) session\(total == 1 ? "" : "s") total:")

        for session in sessions.prefix(5) {
            let name = session.name ?? "Session \(session.id.prefix(8))"
            var detail = "\(session.model), \(session.messageCount) msgs"
            if let project = session.projectName, !project.isEmpty {
                detail += ", \(project)"
            }
            lines.append("• \(name): \(detail)")
        }

        if total > 5 {
            lines.append("...and \(total - 5) more")
        }

        return lines.joined(separator: "\n")
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
