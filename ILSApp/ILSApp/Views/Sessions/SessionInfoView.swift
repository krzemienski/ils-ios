import SwiftUI
import ILSShared

/// Read-only metadata sheet for a single ``ChatSession``.
///
/// Fetches fresh session data from the backend on appearance via `.task`, displaying
/// name, model, status, cost, timestamps, and configuration fields in a grouped `List`.
/// While data is loading a `ProgressView` is shown; on failure an error message with a
/// retry button is presented.
///
/// The toolbar exposes two actions:
/// - **Export** — delegates to ``SessionExportService`` to produce Markdown, then presents
///   a `ShareSheet` for sharing or saving.
/// - **Copy ID** — writes the session UUID to the platform clipboard using
///   `UIPasteboard` on iOS or `NSPasteboard` on macOS, then surfaces a brief confirmation
///   via `ToastModifier`.
///
/// ## Topics
/// ### State
/// - ``loadedSession`` - Full session fetched from the API, overlaying the seed value
/// - ``isLoading`` - Whether the initial or retry fetch is in progress
/// - ``errorMessage`` - Human-readable description of the last fetch failure
struct SessionInfoView: View {
    let session: ChatSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(AppState.self) var appState

    /// The fully-loaded session returned by the API, replacing the seed `session` once fetched.
    @State private var loadedSession: ChatSession?
    /// `true` while the API request is in-flight; drives the `ProgressView` placeholder.
    @State private var isLoading = true
    /// Set to the localised error description when the fetch fails; clears on retry.
    @State private var errorMessage: String?
    @State private var showCopiedToast = false
    @State private var showExportSheet = false
    @State private var exportMarkdown = ""
    @State private var isExporting = false

    private var displaySession: ChatSession {
        loadedSession ?? session
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading session details...")
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(theme.warning)
                    Text("Failed to load session details")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
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
                .scrollContentBackground(.hidden)
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle("Session Info")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
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
                        #if os(iOS)
                        UIPasteboard.general.string = session.id.uuidString
                        #else
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(session.id.uuidString, forType: .string)
                        #endif
                        // SA-MED-4: ToastModifier handles auto-dismiss — no manual timer needed.
                        showCopiedToast = true
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
        exportMarkdown = await SessionExportService.exportMarkdown(
            session: displaySession,
            apiClient: appState.apiClient
        )
        isExporting = false
        showExportSheet = true
    }
}
