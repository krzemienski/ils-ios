import SwiftUI
import Observation
import ILSShared

@MainActor
@Observable
class SettingsViewModel {
    var stats: StatsResponse?
    var config: ConfigInfo?
    var claudeVersion: String?
    var isLoading = false
    var isLoadingConfig = false
    var isSaving = false
    var isTestingConnection = false
    var error: Error?

    private var client: APIClient?

    init() {}

    func configure(client: APIClient) {
        self.client = client
    }

    func loadAll() async {
        async let statsTask: () = loadStats()
        async let configTask: () = loadConfig()
        async let healthTask: () = loadHealth()
        _ = await (statsTask, configTask, healthTask)
    }

    func loadHealth() async {
        guard let client else { return }
        do {
            let response = try await client.getHealth()
            claudeVersion = response.claudeVersion
        } catch {
            claudeVersion = nil
        }
    }

    func loadStats() async {
        guard let client else { return }
        isLoading = true
        do {
            let response: APIResponse<StatsResponse> = try await client.get("/stats")
            stats = response.data
        } catch {
            self.error = error
        }
        isLoading = false
    }

    func loadConfig(scope: String = "user") async {
        guard let client else { return }
        isLoadingConfig = true
        do {
            let response: APIResponse<ConfigInfo> = try await client.get("/config?scope=\(scope)")
            config = response.data
        } catch {
            self.error = error
        }
        isLoadingConfig = false
    }

    func testConnection() async {
        guard let client else { return }
        isTestingConnection = true
        defer { isTestingConnection = false }
        do {
            _ = try await client.healthCheck()
        } catch {
            self.error = error
        }
    }

    func saveConfig(model: String, colorScheme: String) async -> String? {
        guard let client else { return "Client not configured" }
        isSaving = true
        defer { isSaving = false }

        guard var currentConfig = config?.content else {
            return "No configuration loaded"
        }

        currentConfig.model = model
        if currentConfig.theme == nil {
            currentConfig.theme = ThemeConfig(colorScheme: colorScheme, accentColor: nil)
        } else {
            currentConfig.theme?.colorScheme = colorScheme
        }

        do {
            let request = UpdateConfigRequest(scope: config?.scope ?? "user", content: currentConfig)
            let response: APIResponse<ConfigInfo> = try await client.put("/config", body: request)
            if let updatedConfig = response.data {
                config = updatedConfig
                if !updatedConfig.isValid {
                    return updatedConfig.errors?.joined(separator: "\n") ?? "Configuration validation failed"
                }
            }
            return nil
        } catch {
            return "Failed to save: \(error.localizedDescription)"
        }
    }

    func saveConfigToggle(key: String, value: Bool) async -> String? {
        guard let client else { return "Client not configured" }
        isSaving = true
        defer { isSaving = false }

        guard var currentConfig = config?.content else {
            return "No configuration loaded"
        }

        // Update the specific toggle
        switch key {
        case "alwaysThinkingEnabled":
            currentConfig.alwaysThinkingEnabled = value
        case "includeCoAuthoredBy":
            currentConfig.includeCoAuthoredBy = value
        default:
            return "Unknown config key: \(key)"
        }

        do {
            let request = UpdateConfigRequest(scope: config?.scope ?? "user", content: currentConfig)
            let response: APIResponse<ConfigInfo> = try await client.put("/config", body: request)
            if let updatedConfig = response.data {
                config = updatedConfig
                if !updatedConfig.isValid {
                    return updatedConfig.errors?.joined(separator: "\n") ?? "Configuration validation failed"
                }
            }
            return nil
        } catch {
            return "Failed to save: \(error.localizedDescription)"
        }
    }
}
