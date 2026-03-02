import AppIntents
import Foundation

/// Lists ILS projects and returns a formatted summary with count and names.
@available(iOS 16.0, *)
struct ListProjectsIntent: AppIntent {
    static var title: LocalizedStringResource = "List Projects"
    static var description = IntentDescription("List ILS projects and their session counts")

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let baseURL = UserDefaults.standard.string(forKey: "serverURL") ?? "http://localhost:9999"
        guard let url = URL(string: "\(baseURL)/api/v1/projects?limit=50") else {
            return .result(value: "Error: Invalid server URL")
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
                return .result(value: "Unable to reach ILS server")
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            // COD-MED-2: try? is intentional — App Intents must always return a result.
            // Falls back to empty list if response can't be decoded.
            if let apiResponse = try? decoder.decode(ListProjectsAPIResponse.self, from: data),
               let items = apiResponse.data?.items {
                return .result(value: formatProjectList(items))
            }

            return .result(value: "No projects found")
        } catch {
            return .result(value: "Error: \(error.localizedDescription)")
        }
    }

    private func formatProjectList(_ projects: [ListProjectData]) -> String {
        guard !projects.isEmpty else {
            return "No projects found"
        }
        let count = projects.count
        var lines = ["\(count) project\(count == 1 ? "" : "s"):"]
        for project in projects.prefix(10) {
            let sessions = project.sessionCount ?? 0
            lines.append("• \(project.name) (\(sessions) session\(sessions == 1 ? "" : "s"))")
        }
        if count > 10 {
            lines.append("… and \(count - 10) more")
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

private struct ListProjectsAPIResponse: Decodable {
    let success: Bool
    let data: ListProjectsPaginatedResponse?
}

private struct ListProjectsPaginatedResponse: Decodable {
    let items: [ListProjectData]
    let total: Int
    let hasMore: Bool?
}

private struct ListProjectData: Decodable {
    let id: String
    let name: String
    let path: String
    let defaultModel: String
    let sessionCount: Int?
    let description: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, path, defaultModel, sessionCount, description
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.path = try container.decode(String.self, forKey: .path)
        // COD-MED-4: try? with defaults is intentional — external projects may lack these fields.
        self.defaultModel = (try? container.decode(String.self, forKey: .defaultModel)) ?? "sonnet"
        self.sessionCount = try container.decodeIfPresent(Int.self, forKey: .sessionCount)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
    }
}
