import SwiftUI
import ILSShared

/// Standalone toolbar providing session management actions for ``ChatView``.
///
/// Extracted from ``ChatView`` (SUIA-004) to reduce complexity and enable independent
/// preview and testing. All mutations are expressed as callbacks so the toolbar remains
/// free of sheet/action state and stays purely presentational.
///
/// ## Topics
/// ### Inputs
/// - ``session`` - The chat session whose metadata is displayed in the menu
/// - ``multiSessionVM`` - Provides pin state for the pin/unpin button
/// - ``horizontalSizeClass`` - Controls pin button visibility (regular width only)
/// - ``onBack`` - Optional back button shown in leading position (iOS only)
///
/// ### Action Callbacks
/// - ``onRename`` - Called when the user taps "Rename"
/// - ``onFork`` - Called when the user taps "Fork Session"
/// - ``onForkTree`` - Called when the user taps "Fork Tree"
/// - ``onSessionMemory`` - Called when the user taps "Session Memory"
/// - ``onExport`` - Called when the user taps "Export"
/// - ``onInfo`` - Called when the user taps "Session Info"
/// - ``onDelete`` - Called when the user taps "Delete Session"
/// - ``onSearch`` - Called when the user taps the search button
/// - ``onPinToggle`` - Called when the user taps the pin/unpin button
struct ChatToolbar: ToolbarContent {

    // MARK: - Inputs

    /// The chat session being managed.
    let session: ChatSession
    /// View model providing pin state for the current session.
    let multiSessionVM: MultiSessionViewModel
    /// Optional back handler — when provided replaces the hamburger with a back button (iOS).
    var onBack: (() -> Void)? = nil
    /// Horizontal size class — pin button is only shown at `.regular` width (iPad/Mac).
    var horizontalSizeClass: UserInterfaceSizeClass? = nil

    // MARK: - Action Callbacks

    var onRename: () -> Void
    var onFork: () -> Void
    var onForkTree: () -> Void
    var onSessionMemory: () -> Void
    var onExport: () -> Void
    var onInfo: () -> Void
    var onDelete: () -> Void
    var onSearch: () -> Void
    var onPinToggle: () -> Void

    // MARK: - Environment

    @Environment(\.theme) private var theme: ThemeSnapshot

    // MARK: - Body

    var body: some ToolbarContent {
        #if os(iOS)
        if let onBack {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 17))
                    }
                    .foregroundStyle(theme.accent)
                }
                .accessibilityLabel("Go back")
            }
        }
        #endif

        // Connection quality indicator — only visible when online (offline state shown by OfflineIndicator).
        ToolbarItem(placement: .automatic) {
            if ConnectionQualityService.shared.quality != .offline {
                ConnectionQualityIndicator(
                    quality: ConnectionQualityService.shared.quality,
                    latencyMs: ConnectionQualityService.shared.latencyMs
                )
                .accessibilityIdentifier("connection-quality-indicator")
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                onSearch()
            } label: {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.textSecondary)
            }
            .accessibilityLabel("Search messages")
            .accessibilityIdentifier("search-messages-button")
        }

        // Pin/Unpin button — iPad and Mac only (regular horizontal size class).
        if horizontalSizeClass == .regular {
            ToolbarItem(placement: .navigationBarTrailing) {
                let isPinned = multiSessionVM.isPinned(session)
                Button {
                    onPinToggle()
                } label: {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .foregroundStyle(isPinned ? theme.accent : theme.textSecondary)
                }
                .accessibilityLabel(isPinned ? "Unpin from Split View" : "Pin to Split View")
                .accessibilityIdentifier("pin-session-button")
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    onRename()
                } label: {
                    Label("Rename", systemImage: "pencil")
                }

                Button {
                    onFork()
                } label: {
                    Label("Fork Session", systemImage: "arrow.branch")
                }
                .accessibilityIdentifier("fork-session-button")

                Button {
                    onForkTree()
                } label: {
                    Label("Fork Tree", systemImage: "point.3.connected.trianglepath.dotted")
                }
                .accessibilityIdentifier("fork-tree-button")

                Button {
                    onSessionMemory()
                } label: {
                    Label("Session Memory", systemImage: "note.text")
                }
                .accessibilityIdentifier("session-memory-button")

                Button {
                    onExport()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }

                Button(action: onInfo) {
                    Label("Session Info", systemImage: "info.circle")
                }
                .accessibilityIdentifier("session-info-button")

                Divider()

                if let cost = session.totalCostUSD {
                    Text("Cost: $\(cost, specifier: "%.4f")")
                }
                Text("Model: \(session.model)")

                if let projectName = session.projectName {
                    Text("Project: \(projectName)")
                }
                if session.source == .external {
                    Text("Source: Claude Code")
                }

                Divider()

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete Session", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityIdentifier("chat-menu-button")
            .accessibilityLabel("Chat options menu")
            .accessibilityHint("Shows rename, fork, export, and other session options")
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        Text("Chat Content")
            .navigationTitle("Preview Session")
            #if os(iOS)
            .inlineNavigationBarTitle()
            #endif
            .toolbar {
                ChatToolbar(
                    session: ChatSession(
                        id: UUID(),
                        name: "Preview Session",
                        model: "claude-sonnet-4-5",
                        permissionMode: .default,
                        status: .active,
                        messageCount: 5,
                        source: .ils,
                        createdAt: Date(),
                        lastActiveAt: Date()
                    ),
                    multiSessionVM: MultiSessionViewModel(),
                    onRename: {},
                    onFork: {},
                    onForkTree: {},
                    onSessionMemory: {},
                    onExport: {},
                    onInfo: {},
                    onDelete: {},
                    onSearch: {},
                    onPinToggle: {}
                )
            }
    }
    .environment(MultiSessionViewModel())
}
