import Foundation
import ILSShared

@MainActor
class PluginsViewModel: BaseViewModel<PluginItem> {
    /// Convenience accessor for plugins
    var plugins: [PluginItem] {
        items
    }

    override var resourcePath: String {
        "/plugins"
    }

    override var loadingStateText: String {
        "Loading plugins..."
    }

    override var emptyStateText: String {
        if isLoading {
            return loadingStateText
        }
        return items.isEmpty ? "No plugins installed" : ""
    }

    func loadPlugins() async {
        await loadItems()
    }

    func retryLoadPlugins() async {
        await retryLoad()
    }

    func installPlugin(name: String, marketplace: String) async {
        do {
            let request = InstallPluginRequest(pluginName: name, marketplace: marketplace)
            let response: APIResponse<PluginItem> = try await client.post("/plugins/install", body: request)
            if let plugin = response.data {
                items.append(plugin)
            }
        } catch {
            self.error = error
            print("❌ Failed to install plugin '\(name)': \(error.localizedDescription)")
        }
    }

    func uninstallPlugin(_ plugin: PluginItem) async {
        do {
            let _: APIResponse<DeletedResponse> = try await client.delete("/plugins/\(plugin.name)")
            items.removeAll { $0.id == plugin.id }
        } catch {
            self.error = error
            print("❌ Failed to uninstall plugin '\(plugin.name)': \(error.localizedDescription)")
        }
    }

    func enablePlugin(_ plugin: PluginItem) async {
        do {
            let _: APIResponse<EnabledResponse> = try await client.post("/plugins/\(plugin.name)/enable", body: EmptyBody())
            if let index = items.firstIndex(where: { $0.id == plugin.id }) {
                var updated = items[index]
                updated.isEnabled = true
                items[index] = updated
            }
        } catch {
            self.error = error
            print("❌ Failed to enable plugin '\(plugin.name)': \(error.localizedDescription)")
        }
    }

    func disablePlugin(_ plugin: PluginItem) async {
        do {
            let _: APIResponse<EnabledResponse> = try await client.post("/plugins/\(plugin.name)/disable", body: EmptyBody())
            if let index = items.firstIndex(where: { $0.id == plugin.id }) {
                var updated = items[index]
                updated.isEnabled = false
                items[index] = updated
            }
        } catch {
            self.error = error
            print("❌ Failed to disable plugin '\(plugin.name)': \(error.localizedDescription)")
        }
    }
}

// MARK: - Request Types

struct InstallPluginRequest: Encodable {
    let pluginName: String
    let marketplace: String
}

struct EnabledResponse: Decodable {
    let enabled: Bool
}
