import AppIntents
import Foundation

// MARK: - Session Entity

/// App Entity representing a Claude Code session for Siri and Shortcuts integration.
@available(iOS 16.0, *)
struct SessionEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Session")
    static var defaultQuery = SessionEntityQuery()

    var id: String
    var name: String
    var model: String
    var messageCount: Int
    var projectName: String?

    var displayRepresentation: DisplayRepresentation {
        let subtitle = if let projectName, !projectName.isEmpty {
            "\(model) \u{00B7} \(messageCount) msgs \u{00B7} \(projectName)"
        } else {
            "\(model) \u{00B7} \(messageCount) msgs"
        }
        return DisplayRepresentation(title: "\(name)", subtitle: "\(subtitle)")
    }
}

// MARK: - Session Entity Query

@available(iOS 16.0, *)
struct SessionEntityQuery: EntityQuery {

    func entities(for identifiers: [String]) async throws -> [SessionEntity] {
        let allSessions = try await fetchSessions()
        let idSet = Set(identifiers)
        return allSessions.filter { idSet.contains($0.id) }
    }

    func suggestedEntities() async throws -> [SessionEntity] {
        try await fetchSessions()
    }

    // MARK: - Private

    private func fetchSessions() async throws -> [SessionEntity] {
        let baseURL = UserDefaults.standard.string(forKey: "serverURL") ?? "http://localhost:9999"
        guard let url = URL(string: "\(baseURL)/api/v1/sessions?page=1&limit=20") else {
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        // Apply API key if available
        if let apiKey = loadAPIKey(), !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let apiResponse = try decoder.decode(IntentAPIResponse<IntentPaginatedResponse>.self, from: data)
        guard let paginatedData = apiResponse.data else { return [] }

        return paginatedData.items.map { session in
            SessionEntity(
                id: session.id,
                name: session.name ?? "Session \(session.id.prefix(8))",
                model: session.model,
                messageCount: session.messageCount,
                projectName: session.projectName
            )
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

// MARK: - Lightweight Decodable Models for Intents

/// Minimal session model for intent decoding (avoids importing ILSShared into App Intents context).
private struct IntentSessionData: Decodable {
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
        // id can be UUID string
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.model = (try? container.decode(String.self, forKey: .model)) ?? "sonnet"
        self.messageCount = (try? container.decode(Int.self, forKey: .messageCount)) ?? 0
        self.projectName = try container.decodeIfPresent(String.self, forKey: .projectName)
    }
}

private struct IntentAPIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
}

private struct IntentPaginatedResponse: Decodable {
    let items: [IntentSessionData]
    let total: Int
    let hasMore: Bool?
}
