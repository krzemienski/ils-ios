import AppIntents
import Foundation

/// Returns detailed information about a Claude Code session.
@available(iOS 16.0, *)
struct GetSessionInfoIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Session Info"
    static var description = IntentDescription("Get information about a Claude Code session")

    @Parameter(title: "Session")
    var session: SessionEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Get info for \(\.$session)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let baseURL = UserDefaults.standard.string(forKey: "serverURL") ?? "http://localhost:9999"
        guard let url = URL(string: "\(baseURL)/api/v1/sessions/\(session.id)") else {
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
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                // Fall back to cached entity data
                return .result(value: formatEntityInfo())
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            if let json = try? decoder.decode(SessionDetailResponse.self, from: data),
               let detail = json.data {
                return .result(value: formatDetailedInfo(detail))
            }

            // Fall back to entity data
            return .result(value: formatEntityInfo())
        } catch {
            // Network error — return what we have from the entity
            return .result(value: formatEntityInfo())
        }
    }

    private func formatEntityInfo() -> String {
        var parts = ["\(session.name): \(session.model), \(session.messageCount) messages"]
        if let project = session.projectName, !project.isEmpty {
            parts.append("Project: \(project)")
        }
        return parts.joined(separator: "\n")
    }

    private func formatDetailedInfo(_ detail: SessionDetailData) -> String {
        var lines: [String] = []
        lines.append("Session: \(detail.name ?? session.name)")
        lines.append("Model: \(detail.model)")
        lines.append("Messages: \(detail.messageCount)")
        lines.append("Status: \(detail.status)")
        if let project = detail.projectName, !project.isEmpty {
            lines.append("Project: \(project)")
        }
        if let cost = detail.totalCostUSD, cost > 0 {
            lines.append("Cost: $\(String(format: "%.4f", cost))")
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

private struct SessionDetailResponse: Decodable {
    let success: Bool
    let data: SessionDetailData?
}

private struct SessionDetailData: Decodable {
    let id: String
    let name: String?
    let model: String
    let status: String
    let messageCount: Int
    let totalCostUSD: Double?
    let projectName: String?
}
