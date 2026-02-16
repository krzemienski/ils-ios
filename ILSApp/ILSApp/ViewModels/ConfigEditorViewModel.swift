import SwiftUI
import ILSShared

@MainActor
class ConfigEditorViewModel: ObservableObject {
    @Published var configJson = ""
    @Published var isLoading = false
    @Published var error: Error?

    private var client: APIClient?

    init() {}

    func configure(client: APIClient) {
        self.client = client
    }

    func loadConfig(scope: String) async {
        guard let client else { return }
        isLoading = true
        do {
            let response: APIResponse<ConfigInfo> = try await client.get("/config?scope=\(scope)")
            if let config = response.data {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                do {
                    let data = try encoder.encode(config.content)
                    if let json = String(data: data, encoding: .utf8) {
                        configJson = json
                    }
                } catch {
                    AppLogger.shared.error("Failed to encode config content: \(error)", category: "config")
                }
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }

    func saveConfig(scope: String, json: String) async -> [String] {
        guard let client else { return ["Client not configured"] }
        guard let data = json.data(using: .utf8) else {
            return ["Invalid JSON format"]
        }
        let content: ClaudeConfig
        do {
            content = try JSONDecoder().decode(ClaudeConfig.self, from: data)
        } catch {
            AppLogger.shared.error("Failed to decode config JSON: \(error)", category: "config")
            return ["Invalid JSON format: \(error.localizedDescription)"]
        }
        do {
            let request = UpdateConfigRequest(scope: scope, content: content)
            let response: APIResponse<ConfigInfo> = try await client.put("/config", body: request)
            if let config = response.data, !config.isValid {
                return config.errors ?? []
            }
        } catch {
            return ["Failed to save: \(error.localizedDescription)"]
        }
        return []
    }
}
