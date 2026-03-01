import AppIntents
import Foundation

/// Shared URLSession for App Intents with `waitsForConnectivity` enabled.
/// Defined once so all intent structs reuse the same configuration.
@available(iOS 16.0, *)
enum IntentURLSession {
    static let shared: URLSession = {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()
}

/// Creates a new Claude Code session via the ILS backend.
@available(iOS 16.0, *)
struct CreateSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Create New Session"
    static let description = IntentDescription("Create a new Claude Code session in ILS")

    @Parameter(title: "Name", default: "New Session")
    var name: String

    @Parameter(title: "Model", default: .sonnet)
    var model: SessionModel

    @Parameter(title: "Project Path")
    var projectPath: String?

    @Parameter(title: "Skill Name")
    var skillName: String?

    @Parameter(title: "Initial Prompt")
    var initialPrompt: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Create session \(\.$name) with \(\.$model)") {
            \.$projectPath
            \.$skillName
            \.$initialPrompt
        }
    }

    /// Codable request body for session creation.
    private struct CreateSessionBody: Encodable {
        let name: String
        let model: String
        let projectPath: String?
        let skillName: String?
        let initialPrompt: String?

        enum CodingKeys: String, CodingKey {
            case name
            case model
            case projectPath = "project_path"
            case skillName = "skill_name"
            case initialPrompt = "initial_prompt"
        }
    }

    /// Codable response wrapper matching the backend's APIResponse<T>.
    private struct CreateSessionAPIResponse: Decodable {
        let success: Bool
        let data: SessionData?

        struct SessionData: Decodable {
            let id: String
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let baseURL = UserDefaults.standard.string(forKey: "serverURL") ?? "http://localhost:9999"
        guard let url = URL(string: "\(baseURL)/api/v1/sessions") else {
            return .result(value: "Error: Invalid server URL")
        }

        let body = CreateSessionBody(
            name: name,
            model: model.rawValue,
            projectPath: projectPath,
            skillName: skillName,
            initialPrompt: initialPrompt
        )
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

        // Apply API key if available
        if let apiKey = loadAPIKey(), !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await IntentURLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .result(value: "Error: Invalid response from server")
            }

            if (200...299).contains(httpResponse.statusCode) {
                // Extract the session ID using Codable
                do {
                    let decoded = try JSONDecoder().decode(CreateSessionAPIResponse.self, from: data)
                    if let sessionId = decoded.data?.id {
                        return .result(value: "Created session \"\(name)\" (ID: \(sessionId.prefix(8))...)")
                    }
                } catch {
                    // Decode failed but session was created — fall through
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

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Model")
    static let caseDisplayRepresentations: [SessionModel: DisplayRepresentation] = [
        .sonnet: "Sonnet",
        .opus: "Opus",
        .haiku: "Haiku"
    ]
}
