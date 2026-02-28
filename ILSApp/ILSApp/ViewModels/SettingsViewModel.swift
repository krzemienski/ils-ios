import Foundation
import Observation
import ILSShared

@MainActor
@Observable
class SettingsViewModel {
    static let defaultModelID = "claude-sonnet-4-20250514"

    var stats: StatsResponse?
    var config: ConfigInfo?
    /// Effective configuration with per-key scope annotations from /config/effective.
    /// Used by the UI for inheritance badge logic. Not used for writes (saveWithPatch uses `config`).
    var effectiveConfig: EffectiveConfig?
    var claudeVersion: String?
    var isLoading = false
    var isLoadingConfig = false
    var isSaving = false
    var isTestingConnection = false
    var error: Error?

    /// Per-key override lookup for O(1) access. Built from effectiveConfig.overrides.
    private var overrideLookup: [String: ConfigOverride] = [:]
    private var client: APIClient?

    init() {}

    func configure(client: APIClient) {
        self.client = client
    }

    func loadAll() async {
        async let statsTask: () = loadStats()
        async let effectiveTask: () = loadEffectiveConfig()
        async let configTask: () = loadConfig()  // Still needed for saveWithPatch read-modify-write
        async let healthTask: () = loadHealth()
        _ = await (statsTask, effectiveTask, configTask, healthTask)
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

    /// Loads the merged effective configuration from the backend.
    /// The effective config shows which scope won for each key, used by the UI for inheritance badges.
    /// - Parameter bypassCache: When true, passes cacheTTL=0 to skip APIClient's 60s cache.
    ///   Use after saveWithPatch to ensure badges update immediately.
    func loadEffectiveConfig(bypassCache: Bool = false) async {
        guard let client else { return }
        isLoadingConfig = true
        do {
            let cacheTTL: TimeInterval? = bypassCache ? 0 : nil
            let response: APIResponse<EffectiveConfig> = try await client.get(
                "/config/effective",
                cacheTTL: cacheTTL
            )
            effectiveConfig = response.data
            // Build lookup dictionary for O(1) access per setting key
            if let overrides = response.data?.overrides {
                overrideLookup = Dictionary(
                    uniqueKeysWithValues: overrides.map { ($0.key, $0) }
                )
            } else {
                overrideLookup = [:]
            }
        } catch {
            // Non-fatal: if effective config fails, badges will fall back gracefully
            self.error = error
        }
        isLoadingConfig = false
    }

    /// Whether a setting key's effective value comes from a scope other than user.
    /// Returns true (inherited) when: no override data exists for the key, OR the winning scope is not .user.
    func isInherited(key: String) -> Bool {
        guard let override = overrideLookup[key] else {
            return true  // No override means no value set anywhere -- treat as inherited/default
        }
        return override.winningScope != .user
    }

    /// The winning scope for a given key, if available.
    func winningScope(for key: String) -> ConfigScope? {
        overrideLookup[key]?.winningScope
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

    /// Saves server URL to AppState and tests the connection.
    /// Keeps SettingsView thin by moving the Task creation here.
    func saveAndTestConnection(url: String, appState: AppState) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        appState.updateServerURL(trimmed)
        Task {
            await testConnection()
        }
    }

    /// Pre-computed hook event breakdown derived from cached config.
    /// Avoids rebuilding the filtered array on every view body evaluation.
    var hookEventBreakdown: [(String, Int)] {
        guard let hooks = config?.content.hooks else { return [] }
        return hooks.events
            .map { ($0.key, $0.value.count) }
            .filter { $0.1 > 0 }
            .sorted { $0.0 < $1.0 }
    }

    // MARK: - Safe Config Write (read-then-patch)

    /// Loads fresh config from the server, applies a single-field delta, and PUTs the full
    /// config back. This preserves CLI-only fields (hooks, env, permissions, statusLine,
    /// enabledPlugins, extraKnownMarketplaces) that the iOS app reads but should never overwrite.
    ///
    /// - Parameter delta: A closure that mutates ONLY the intended field(s) on a fresh config copy.
    /// - Returns: An error message string, or `nil` on success.
    func saveWithPatch(applying delta: (inout ClaudeConfig) -> Void) async -> String? {
        guard let client else { return "Client not configured" }
        isSaving = true
        defer { isSaving = false }

        do {
            // Step 1: Load fresh config from server (not from in-memory cache)
            let freshResponse: APIResponse<ConfigInfo> = try await client.get("/config?scope=user")
            guard var freshConfig = freshResponse.data?.content else {
                return "Could not load current configuration"
            }

            // Step 2: Apply the delta closure -- mutates ONLY the intended field(s)
            delta(&freshConfig)

            // Step 3: PUT the FULL config back (preserving hooks, env, permissions, etc.)
            let scope = freshResponse.data?.scope ?? .user
            let request = UpdateConfigRequest(scope: scope, content: freshConfig)
            let putResponse: APIResponse<ConfigInfo> = try await client.put("/config", body: request)
            if let updatedConfig = putResponse.data {
                config = updatedConfig
                if !updatedConfig.isValid {
                    return updatedConfig.errors?.joined(separator: "\n") ?? "Configuration validation failed"
                }
            }
            // Refresh effective config so inheritance badges update immediately
            await loadEffectiveConfig(bypassCache: true)
            return nil
        } catch {
            return "Failed to save: \(error.localizedDescription)"
        }
    }

    func saveConfig(model: String, colorScheme: String) async -> String? {
        return await saveWithPatch { config in
            config.model = model
            if config.theme == nil {
                config.theme = ThemeConfig(colorScheme: colorScheme, accentColor: nil)
            } else {
                config.theme?.colorScheme = colorScheme
            }
        }
    }

    func saveConfigToggle(key: String, value: Bool) async -> String? {
        return await saveWithPatch { config in
            switch key {
            case "alwaysThinkingEnabled":
                config.alwaysThinkingEnabled = value
            case "includeCoAuthoredBy":
                config.includeCoAuthoredBy = value
            default:
                break // Unknown keys silently ignored; caller validates
            }
        }
    }

    // MARK: - Data Deletion

    var isDeleting = false
    var deleteResult: String?

    /// Calls the GDPR "delete all my data" endpoint and updates the UI with results.
    func performDataDeletion() async {
        guard let client else { return }
        isDeleting = true
        deleteResult = nil

        do {
            let response: APIResponse<DataErasureResponse> = try await client.delete("/data/all")
            if let data = response.data {
                let total = data.messagesDeleted + data.sessionsDeleted +
                            data.projectsDeleted + data.themesDeleted +
                            data.fleetHostsDeleted + data.cacheEntriesDeleted
                deleteResult = "Deleted \(total) items (\(data.sessionsDeleted) sessions, \(data.messagesDeleted) messages, \(data.projectsDeleted) projects)"
                HapticManager.notification(.success)
            } else {
                deleteResult = "Failed to delete data. Server returned no data."
                HapticManager.notification(.error)
            }
        } catch {
            deleteResult = "Failed to delete data. Check server connection."
            HapticManager.notification(.error)
        }

        isDeleting = false
    }

    // MARK: - Fire-and-forget wrappers (synchronous entry points for Binding setters)

    /// Updates the default model from a Binding setter without requiring Task/await.
    func updateModel(_ newModel: String) {
        Task {
            _ = await saveConfig(model: newModel, colorScheme: config?.content.theme?.colorScheme ?? "system")
        }
    }

    /// Updates a boolean toggle from a Binding setter without requiring Task/await.
    func updateToggle(key: String, value: Bool) {
        Task {
            _ = await saveConfigToggle(key: key, value: value)
        }
    }
}
