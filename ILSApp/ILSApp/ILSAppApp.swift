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
        }
    }
    @Published var selectedTab: String = "sessions"

    var apiClient: APIClient
    var sseClient: SSEClient

    init() {
        let host = UserDefaults.standard.string(forKey: "serverHost") ?? "localhost"
        let port = UserDefaults.standard.integer(forKey: "serverPort")
        let actualPort = port > 0 ? port : 9090
        let url = "http://\(host):\(actualPort)"
        self.serverURL = url
        self.apiClient = APIClient(baseURL: url)
        self.sseClient = SSEClient(baseURL: url)
        checkConnection()
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
