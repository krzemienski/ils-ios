import AppIntents
import Foundation

/// Lists recent Claude Code sessions and returns a summary with count and names.
@available(iOS 16.0, *)
struct ListSessionsIntent: AppIntent {
    static var title: LocalizedStringResource = "List Recent Sessions"
    static var description = IntentDescription("List recent Claude Code sessions and their status")

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ShowsSnippetView {
        let baseURL = UserDefaults.standard.string(forKey: "serverURL") ?? "http://localhost:9999"
        guard let url = URL(string: "\(baseURL)/api/v1/sessions?page=1&limit=10") else {
            return .result(value: "Error: Invalid server URL", view: SessionSnippetView(mode: .list([])))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        // Apply API key if available
        if let apiKey = loadAPIKey(), !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await IntentURLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return .result(value: "Unable to reach ILS server", view: SessionSnippetView(mode: .list([])))
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            // COD-MED-2: try? is intentional — App Intents must always return a result.
            // Falls back to empty list if response can't be decoded.
            if let apiResponse = try? decoder.decode(ListSessionsAPIResponse.self, from: data),
               let items = apiResponse.data?.items {
                let snippetSessions = items.map { session in
                    SnippetSessionInfo(
                        id: session.id,
                        name: session.name ?? "Session \(session.id.prefix(8))",
                        model: session.model,
                        messageCount: session.messageCount,
                        isActive: session.status == "active",
                        projectName: session.projectName
                    )
                }
                return .result(value: formatSessionList(items), view: SessionSnippetView(mode: .list(snippetSessions)))
            }

            return .result(value: "No sessions found", view: SessionSnippetView(mode: .list([])))
        } catch {
            return .result(value: "Error: \(error.localizedDescription)", view: SessionSnippetView(mode: .list([])))
        }
    }

    private func formatSessionList(_ sessions: [ListSessionData]) -> String {
        guard !sessions.isEmpty else {
            return "No recent sessions"
        }
        let count = sessions.count
        let names = sessions.prefix(5).map { $0.name ?? "Session \($0.id.prefix(8))" }
        var lines = ["\(count) recent session\(count == 1 ? "" : "s"):"]
        lines.append(contentsOf: names.map { "• \($0)" })
        if count > 5 {
            lines.append("… and \(count - 5) more")
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

// MARK: - Response Models

private struct ListSessionsAPIResponse: Decodable {
    let success: Bool
    let data: ListSessionsPaginatedResponse?
}

private struct ListSessionsPaginatedResponse: Decodable {
    let items: [ListSessionData]
    let total: Int
}

private struct ListSessionData: Decodable {
    let id: String
    let name: String?
    let model: String
    let status: String
    let messageCount: Int
    let projectName: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, model, status, messageCount, projectName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        // COD-MED-4: try? with defaults is intentional — external sessions may lack these fields.
        self.model = (try? container.decode(String.self, forKey: .model)) ?? "sonnet"
        self.status = (try? container.decode(String.self, forKey: .status)) ?? "idle"
        self.messageCount = (try? container.decode(Int.self, forKey: .messageCount)) ?? 0
        self.projectName = try container.decodeIfPresent(String.self, forKey: .projectName)
    }
}
