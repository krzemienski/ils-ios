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
        }
    }
}

/// Global application state
@MainActor
class AppState: ObservableObject {
    @Published var selectedProject: Project?
    @Published var isConnected: Bool = false
    @Published var serverURL: String = "http://localhost:8080"

    init() {
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
}
