import SwiftUI
import ILSShared

/// Read-only metadata sheet for a single ``ChatSession``.
///
/// Fetches fresh session data from the backend on appearance via `.task`, displaying
/// name, model, status, cost, timestamps, and configuration fields in a grouped `List`.
/// While data is loading a `ProgressView` is shown; on failure an error message with a
/// retry button is presented.
///
/// A **Checkpoints** section displays the current checkpoint count and provides a
/// `NavigationLink` into ``SessionCheckpointsView`` for creating, deleting, and restoring
/// named snapshots.
///
/// The toolbar exposes three actions:
/// - **Export** — opens ``SessionExportPickerSheet`` to choose JSON, Markdown, or PDF.
/// - **Create Checkpoint** — presents a name-input alert then delegates to
///   ``SessionCheckpointsViewModel/createCheckpoint(sessionId:name:)``.
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
/// - ``checkpointsViewModel`` - Manages checkpoint list and creation
struct SessionInfoView: View {
    let session: ChatSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(AppState.self) var appState

    @State private var viewModel = SessionInfoViewModel()
    @State private var checkpointViewModel = CheckpointViewModel()
    @State private var checkpointsViewModel = SessionCheckpointsViewModel()
    @State private var healthViewModel = SessionHealthViewModel()
    @State private var showCopiedToast = false
    @State private var showExportSheet = false
    @State private var showExportPickerSheet = false
    @State private var showFileBrowser = false
    @State private var showModelUpdatedToast = false
    @State private var showRecordings = false
    @State private var showAddCheckpointAlert = false
    @State private var newCheckpointName = ""

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

                        Section("Checkpoints") {
                            NavigationLink {
                                SessionCheckpointsView(session: displaySession)
                                    .environment(appState)
                            } label: {
                                LabeledContent(
                                    "Checkpoints",
                                    value: "\(checkpointsViewModel.checkpoints.count)"
                                )
                            }
                        }

                        Section("Cost & Usage") {
                            if let cost = displaySession.totalCostUSD {
                                LabeledContent("Total Cost", value: String(format: "$%.4f", cost))
                            } else {
                                LabeledContent("Total Cost", value: "N/A")
                            }
                        }

                        Section("Health Score") {
                            if healthViewModel.isLoadingHealth {
                                HStack {
                                    ProgressView()
                                        .controlSize(.small)
                                    Spacer()
                                }
                            } else {
                                HStack {
                                    SessionHealthBadge(
                                        healthScore: healthViewModel.healthScore,
                                        showLabel: true
                                    )
                                    Spacer()
                                    NavigationLink {
                                        SessionHealthDetailView(session: displaySession)
                                    } label: {
                                        Text("Details")
                                    }
                                }
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

                        Section {
                            Button {
                                showRecordings = true
                            } label: {
                                Label("Recordings", systemImage: "record.circle")
                                    .foregroundStyle(theme.textPrimary)
                            }
                        }

                        if displaySession.claudeSessionId != nil {
                            Section("Files") {
                                Button {
                                    showFileBrowser = true
                                } label: {
                                    Label("Changed Files", systemImage: "doc.text.magnifyingglass")
                                }
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
                        dismiss()
                        appState.navigationIntent = .sessionForkTree(displaySession)
                    } label: {
                        Image(systemName: "arrow.triangle.branch")
                    }
                    .accessibilityLabel("View Fork Tree")

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
                        showExportPickerSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }

                    Button {
                        newCheckpointName = ""
                        showAddCheckpointAlert = true
                    } label: {
                        Image(systemName: "bookmark.badge.plus")
                    }

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
            .sheet(isPresented: $showExportPickerSheet) {
                SessionExportPickerSheet(session: displaySession)
                    .environment(appState)
            }
            .sheet(isPresented: $showFileBrowser) {
                NavigationStack {
                    SessionFileBrowserView(session: displaySession)
                }
                .presentationBackground(theme.bgPrimary)
            }
            .sheet(isPresented: $showRecordings) {
                NavigationStack {
                    SessionRecordingsView(session: displaySession)
                        .environment(appState)
                }
            }
            .alert("New Checkpoint", isPresented: $showAddCheckpointAlert) {
                TextField("Checkpoint name", text: $newCheckpointName)
                Button("Save") {
                    let name = newCheckpointName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    Task {
                        await checkpointsViewModel.createCheckpoint(
                            sessionId: session.id,
                            name: name
                        )
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter a name for this checkpoint snapshot.")
            }
            .toast(isPresented: $showCopiedToast, message: "Session ID copied")
            .task {
                viewModel.configure(client: appState.apiClient)
                checkpointViewModel.configure(client: appState.apiClient)
                checkpointsViewModel.configure(client: appState.apiClient)
                healthViewModel.configure(client: appState.apiClient)
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { await viewModel.loadSession(id: session.id) }
                    group.addTask { await healthViewModel.loadHealth(sessionId: session.id) }
                    group.addTask { await checkpointsViewModel.loadCheckpoints(sessionId: session.id) }
                }
            }
        }
    }
}
