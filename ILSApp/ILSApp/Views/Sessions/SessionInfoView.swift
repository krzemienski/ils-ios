import SwiftUI
import ILSShared

struct SessionInfoView: View {
    let session: ChatSession
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    @State private var loadedSession: ChatSession?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCopiedToast = false
    @State private var showExportSheet = false
    @State private var exportMarkdown = ""
    @State private var isExporting = false

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
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        Button {
                            Task { await exportSession() }
                        } label: {
                            if isExporting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        .disabled(isExporting)

                        Button {
                            UIPasteboard.general.string = session.id.uuidString
                            showCopiedToast = true
                            Task {
                                try? await Task.sleep(for: .seconds(2))
                                showCopiedToast = false
                            }
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showExportSheet) {
                ShareSheet(text: exportMarkdown, fileName: "\(displaySession.name ?? "session").md")
            }
            .toast(isPresented: $showCopiedToast, message: "Session ID copied")
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

    private func exportSession() async {
        isExporting = true
        let s = displaySession
        var md = "# Session: \(s.name ?? "Unnamed")\n\n"
        md += "Model: \(s.model.capitalized)\n"
        md += "Status: \(s.status.rawValue.capitalized)\n"
        md += "Created: \(s.createdAt.formatted())\n"
        md += "Last Active: \(s.lastActiveAt.formatted())\n"
        if let cost = s.totalCostUSD {
            md += "Cost: $\(String(format: "%.4f", cost))\n"
        }
        md += "\n---\n\n"

        // Fetch messages
        do {
            let response: APIResponse<ListResponse<Message>> = try await appState.apiClient.get("/sessions/\(session.id.uuidString)/messages?limit=500")
            if let messages = response.data?.items {
                for message in messages {
                    let role = message.role.rawValue.capitalized
                    md += "## \(role)\n\n\(message.content)\n\n"
                }
            }
        } catch {
            md += "_Failed to load messages: \(error.localizedDescription)_\n"
        }

        exportMarkdown = md
        isExporting = false
        showExportSheet = true
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let text: String
    let fileName: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let data = Data(text.utf8)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? data.write(to: tempURL)
        let controller = UIActivityViewController(
            activityItems: [tempURL],
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
