import SwiftUI
import ILSShared

@main
struct ILSAppApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    appState.handleURL(url)
                }
        }
    }
}

/// Global application state
@MainActor
class AppState: ObservableObject {
    @Published var selectedProject: Project?
    @Published var isConnected: Bool = false
    @Published var serverURL: String = "http://localhost:8080" {
        didSet {
            apiClient = APIClient(baseURL: serverURL)
            sseClient = SSEClient(baseURL: serverURL)
            checkConnection()

            // Save to Keychain with biometric protection if enabled
            Task {
                do {
                    let requireBiometrics = UserDefaults.standard.bool(forKey: "biometric_protection_enabled")
                    try await keychainService.saveCredential(
                        key: "ils_server_url",
                        value: serverURL,
                        requireBiometrics: requireBiometrics
                    )
                } catch {
                    // Silently fail - not critical if save fails
                }
            }
        }
    }
    @Published var selectedTab: String = "sessions"

    var apiClient: APIClient
    var sseClient: SSEClient
    let keychainService = KeychainService()

    init() {
        let url = "http://localhost:9090" // Default
        self.serverURL = url
        self.apiClient = APIClient(baseURL: url)
        self.sseClient = SSEClient(baseURL: url)

        // Migrate from UserDefaults to Keychain
        Task {
            await migrateCredentials()
            checkConnection()
        }
    }

    /// Migrate credentials from UserDefaults to Keychain
    private func migrateCredentials() async {
        do {
            // Try to load from Keychain first
            if let savedURL = try? await keychainService.getCredential(key: "ils_server_url") {
                serverURL = savedURL
                return
            }

            // Keychain is empty - migrate from UserDefaults
            let host = UserDefaults.standard.string(forKey: "serverHost")
            let port = UserDefaults.standard.integer(forKey: "serverPort")

            if let host = host, port > 0 {
                // Found UserDefaults data - migrate it
                let migratedURL = "http://\(host):\(port)"
                try await keychainService.saveCredential(key: "ils_server_url", value: migratedURL)
                serverURL = migratedURL

                // Clean up old UserDefaults keys
                UserDefaults.standard.removeObject(forKey: "serverHost")
                UserDefaults.standard.removeObject(forKey: "serverPort")
            } else if let host = host {
                // Only host found, use default port
                let migratedURL = "http://\(host):9090"
                try await keychainService.saveCredential(key: "ils_server_url", value: migratedURL)
                serverURL = migratedURL

                UserDefaults.standard.removeObject(forKey: "serverHost")
                UserDefaults.standard.removeObject(forKey: "serverPort")
            }
        } catch {
            // Migration failed - fall back to defaults
            // serverURL is already set to default in init
        }
    }

    func checkConnection() {
        Task {
            do {
                let client = APIClient(baseURL: serverURL)
                _ = try await client.healthCheck()
                isConnected = true
            } catch {
                isConnected = false
            }
        }
    }

    func handleURL(_ url: URL) {
        guard url.scheme == "ils" else { return }

        switch url.host {
        case "projects":
            selectedTab = "projects"
        case "plugins":
            selectedTab = "plugins"
        case "mcp":
            selectedTab = "mcp"
        case "sessions":
            selectedTab = "sessions"
        case "settings":
            selectedTab = "settings"
        case "skills":
            selectedTab = "skills"
        default:
            break
        }
    }
}
