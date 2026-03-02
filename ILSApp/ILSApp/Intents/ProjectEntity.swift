import AppIntents
import Foundation

// MARK: - Project Entity

/// App Entity representing an ILS project for Siri and Shortcuts integration.
@available(iOS 16.0, *)
struct ProjectEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Project")
    static var defaultQuery = ProjectEntityQuery()

    var id: String
    var name: String
    var path: String
    var defaultModel: String
    var sessionCount: Int
    var projectDescription: String?

    var displayRepresentation: DisplayRepresentation {
        let subtitle = if let projectDescription, !projectDescription.isEmpty {
            "\(defaultModel) \u{00B7} \(sessionCount) sessions \u{00B7} \(projectDescription)"
        } else {
            "\(defaultModel) \u{00B7} \(sessionCount) sessions"
        }
        return DisplayRepresentation(title: "\(name)", subtitle: "\(subtitle)")
    }
}

// MARK: - Project Entity Query

@available(iOS 16.0, *)
struct ProjectEntityQuery: EntityQuery {

    func entities(for identifiers: [String]) async throws -> [ProjectEntity] {
        let allProjects = try await fetchProjects()
        let idSet = Set(identifiers)
        return allProjects.filter { idSet.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ProjectEntity] {
        try await fetchProjects()
    }

    // MARK: - Private

    private func fetchProjects() async throws -> [ProjectEntity] {
        let baseURL = UserDefaults.standard.string(forKey: AppConstants.serverURLKey) ?? AppConstants.defaultServerURL
        guard let url = URL(string: "\(baseURL)/api/v1/projects?limit=50") else {
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

        let (data, response) = try await IntentURLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let apiResponse = try decoder.decode(IntentProjectAPIResponse.self, from: data)
        guard let listData = apiResponse.data else { return [] }

        return listData.items.map { project in
            ProjectEntity(
                id: project.id,
                name: project.name,
                path: project.path,
                defaultModel: project.defaultModel,
                sessionCount: project.sessionCount ?? 0,
                projectDescription: project.description
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

/// Minimal project model for intent decoding (avoids importing ILSShared into App Intents context).
private struct IntentProjectData: Decodable {
    let id: String
    let name: String
    let path: String
    let defaultModel: String
    let description: String?
    let sessionCount: Int?

    private enum CodingKeys: String, CodingKey {
        case id, name, path, defaultModel, description, sessionCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // id is a UUID — decode as string
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.path = try container.decode(String.self, forKey: .path)
        // COD-MED-4: try? with defaults is intentional — external projects may lack these fields.
        self.defaultModel = (try? container.decode(String.self, forKey: .defaultModel)) ?? "sonnet"
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.sessionCount = try container.decodeIfPresent(Int.self, forKey: .sessionCount)
    }
}

private struct IntentProjectAPIResponse: Decodable {
    let success: Bool
    let data: IntentProjectListResponse?
}

private struct IntentProjectListResponse: Decodable {
    let items: [IntentProjectData]
    let total: Int
    let hasMore: Bool?
}
