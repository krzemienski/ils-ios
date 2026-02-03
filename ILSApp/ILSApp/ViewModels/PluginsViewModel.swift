import Foundation
import ILSShared

@MainActor
class PluginsViewModel: ObservableObject {
    @Published var plugins: [PluginItem] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let client = APIClient()

    /// Empty state text for UI display
    var emptyStateText: String {
        if isLoading {
            return "Loading plugins..."
        }
        return plugins.isEmpty ? "No plugins installed" : ""
    }

    func loadPlugins() async {
        isLoading = true
        error = nil

        do {
            let response: APIResponse<ListResponse<PluginItem>> = try await client.get("/plugins")
            if let data = response.data {
                plugins = data.items
            }
        } catch {
            self.error = error
            print("❌ Failed to load plugins: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func retryLoadPlugins() async {
        await loadPlugins()
    }

    func installPlugin(name: String, marketplace: String) async {
        do {
            let request = InstallPluginRequest(pluginName: name, marketplace: marketplace)
            let response: APIResponse<PluginItem> = try await client.post("/plugins/install", body: request)
            if let plugin = response.data {
                plugins.append(plugin)
            }
        } catch {
            self.error = error
            print("❌ Failed to install plugin '\(name)': \(error.localizedDescription)")
        }
    }

    func uninstallPlugin(_ plugin: PluginItem) async {
        do {
            let _: APIResponse<DeletedResponse> = try await client.delete("/plugins/\(plugin.name)")
            plugins.removeAll { $0.id == plugin.id }
        } catch {
            self.error = error
            print("❌ Failed to uninstall plugin '\(plugin.name)': \(error.localizedDescription)")
        }
    }

    func enablePlugin(_ plugin: PluginItem) async {
        do {
            let _: APIResponse<EnabledResponse> = try await client.post("/plugins/\(plugin.name)/enable", body: EmptyBody())
            if let index = plugins.firstIndex(where: { $0.id == plugin.id }) {
                var updated = plugins[index]
                updated.isEnabled = true
                plugins[index] = updated
            }
        } catch {
            self.error = error
            print("❌ Failed to enable plugin '\(plugin.name)': \(error.localizedDescription)")
        }
    }

    func disablePlugin(_ plugin: PluginItem) async {
        do {
            let _: APIResponse<EnabledResponse> = try await client.post("/plugins/\(plugin.name)/disable", body: EmptyBody())
            if let index = plugins.firstIndex(where: { $0.id == plugin.id }) {
                var updated = plugins[index]
                updated.isEnabled = false
                plugins[index] = updated
            }
        } catch {
            self.error = error
            print("❌ Failed to disable plugin '\(plugin.name)': \(error.localizedDescription)")
        }
    }
}