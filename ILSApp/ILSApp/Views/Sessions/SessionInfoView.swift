import SwiftUI
import ILSShared

struct SessionInfoView: View {
    let session: ChatSession
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    @State private var loadedSession: ChatSession?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var displaySession: ChatSession {
        loadedSession ?? session
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading session details...")
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(ILSTheme.warning)
                        Text("Failed to load session details")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(ILSTheme.secondaryText)
                        Button("Retry") {
                            Task { await loadSession() }
                        }
                    }
                    .padding()
                } else {
                    List {
                        Section("Session Details") {
                            LabeledContent("Name", value: displaySession.name ?? "Unnamed")
                            LabeledContent("Model", value: displaySession.model.capitalized)
                            LabeledContent("Status", value: displaySession.status.rawValue.capitalized)
                            LabeledContent("Messages", value: "\(displaySession.messageCount)")
                        }

                        Section("Cost & Usage") {
                            if let cost = displaySession.totalCostUSD {
                                LabeledContent("Total Cost", value: String(format: "$%.4f", cost))
                            } else {
                                LabeledContent("Total Cost", value: "N/A")
                            }
                        }

                        Section("Timestamps") {
                            LabeledContent("Created", value: displaySession.createdAt.formatted())
                            LabeledContent("Last Active", value: displaySession.lastActiveAt.formatted())
                        }

                        Section("Configuration") {
                            LabeledContent("Permission Mode", value: displaySession.permissionMode.rawValue)
                            LabeledContent("Source", value: displaySession.source.rawValue)
                            if let projectName = displaySession.projectName {
                                LabeledContent("Project", value: projectName)
                            }
                        }

                        if let claudeId = displaySession.claudeSessionId {
                            Section("Internal") {
                                LabeledContent("Claude Session ID", value: claudeId)
                                    .font(.caption)
                            }
                        }
                    }
                    .darkListStyle()
                }
            }
            .background(ILSTheme.background)
            .navigationTitle("Session Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadSession()
            }
        }
    }

    private func loadSession() async {
        isLoading = true
        errorMessage = nil

        do {
            let response: APIResponse<ChatSession> = try await appState.apiClient.get("/sessions/\(session.id.uuidString)")
            if let data = response.data {
                loadedSession = data
            } else {
                errorMessage = "No session data returned"
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
