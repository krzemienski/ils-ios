import SwiftUI
import ILSShared

/// Displays sessions belonging to a specific project, loaded from Claude Code transcripts
struct ProjectSessionsListView: View {
    let project: Project
    @EnvironmentObject var appState: AppState
    @State private var sessions: [ChatSession] = []
    @State private var isLoading = false
    @State private var error: Error?

    var body: some View {
        List {
            if let error = error {
                ErrorStateView(error: error) {
                    await loadProjectSessions()
                }
            } else if sessions.isEmpty && !isLoading {
                EmptyStateView(
                    title: "No Sessions",
                    systemImage: "bubble.left.and.bubble.right",
                    description: "No Claude Code sessions found for this project"
                )
            } else {
                ForEach(sessions) { session in
                    NavigationLink(destination: ChatView(session: session)) {
                        SessionRowView(session: session)
                    }
                    .contentShape(Rectangle())
                }
            }
        }
        .darkListStyle()
        .navigationTitle("Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .refreshable {
            await loadProjectSessions()
        }
        .overlay {
            if isLoading && sessions.isEmpty {
                ProgressView("Loading sessions...")
            }
        }
        .task {
            await loadProjectSessions()
        }
    }

    private func loadProjectSessions() async {
        isLoading = true
        error = nil

        do {
            let response: APIResponse<SessionScanResponse> = try await appState.apiClient.get("/sessions/scan")
            guard let scanData = response.data else {
                sessions = []
                isLoading = false
                return
            }

            // Filter to sessions matching this project's encodedPath
            let projectSessions = scanData.items
                .filter { $0.encodedProjectPath == project.encodedPath }
                .map { ext -> ChatSession in
                    ChatSession(
                        id: UUID(),
                        claudeSessionId: ext.claudeSessionId,
                        name: ext.name ?? ext.summary,
                        projectName: ext.projectName,
                        model: "sonnet",
                        permissionMode: .default,
                        status: .completed,
                        messageCount: ext.messageCount ?? 0,
                        source: .external,
                        createdAt: ext.createdAt ?? ext.lastActiveAt ?? Date(),
                        lastActiveAt: ext.lastActiveAt ?? Date(),
                        encodedProjectPath: ext.encodedProjectPath,
                        firstPrompt: ext.firstPrompt
                    )
                }
                .sorted { $0.lastActiveAt > $1.lastActiveAt }

            sessions = projectSessions
        } catch {
            self.error = error
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        ProjectSessionsListView(
            project: Project(
                name: "Test Project",
                path: "/Users/nick/Desktop/test",
                encodedPath: "-Users-nick-Desktop-test"
            )
        )
    }
}
