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
/// A **Recovery** section is shown for ILS-managed sessions, providing a `NavigationLink`
/// to ``CheckpointBrowserView`` and a quick "Save Checkpoint Now" action.
///
/// ## Topics
/// ### State
/// - ``viewModel`` - Manages session loading and export via `SessionInfoViewModel`
/// - ``checkpointViewModel`` - Manages checkpoint operations for the session
struct SessionInfoView: View {
    let session: ChatSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(AppState.self) var appState

    @State private var viewModel = SessionInfoViewModel()
    @State private var checkpointViewModel = CheckpointViewModel()
    @State private var showCopiedToast = false
    @State private var showExportSheet = false

    private var bookmarksManager: SessionBookmarksManager { SessionBookmarksManager.shared }

    private var displaySession: ChatSession {
        viewModel.loadedSession ?? session
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading session details...")
                } else if let error = viewModel.errorMessage {
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
                            Task { await viewModel.loadSession(id: session.id) }
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

                        if displaySession.source == .ils {
                            Section("Recovery") {
                                NavigationLink {
                                    CheckpointBrowserView(
                                        session: displaySession,
                                        viewModel: checkpointViewModel
                                    )
                                    .environment(appState)
                                } label: {
                                    Label("Checkpoints", systemImage: "clock.arrow.circlepath")
                                }

                                Button {
                                    Task {
                                        await checkpointViewModel.createCheckpoint(
                                            sessionId: session.id,
                                            label: nil,
                                            isAuto: false
                                        )
                                    }
                                } label: {
                                    Label("Save Checkpoint Now", systemImage: "clock.badge.checkmark")
                                }
                                .disabled(checkpointViewModel.isLoading)
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
                            Task { await bookmarksManager.toggleBookmark(session: displaySession) }
                        } label: {
                            Image(
                                systemName: bookmarksManager.isBookmarked(sessionId: displaySession.id)
                                    ? "bookmark.fill"
                                    : "bookmark"
                            )
                        }
                        .accessibilityLabel(
                            bookmarksManager.isBookmarked(sessionId: displaySession.id)
                                ? "Remove bookmark"
                                : "Add bookmark"
                        )

                        Button {
                            Task {
                                await viewModel.exportSession(session: displaySession)
                                showExportSheet = true
                            }
                        } label: {
                            if viewModel.isExporting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        .disabled(viewModel.isExporting)

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
                ShareSheet(text: viewModel.exportMarkdown, fileName: "\(displaySession.name ?? "session").md")
            }
            .toast(isPresented: $showCopiedToast, message: "Session ID copied")
            .task {
                viewModel.configure(client: appState.apiClient)
                checkpointViewModel.configure(client: appState.apiClient)
                await viewModel.loadSession(id: session.id)
            }
        }
    }
}
