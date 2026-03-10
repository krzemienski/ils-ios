import SwiftUI
import ILSShared

/// List view for browsing and managing backend connections with live health monitoring.
///
/// Displays all registered ``BackendConnection`` entries as rows. Each row shows a
/// color-coded identity dot, a health badge, the backend name, truncated URL, an
/// active indicator, and a context menu. Health polling begins on `onAppear` and
/// pauses on `onDisappear`.
///
/// An empty state is shown when no backends exist, and an inline error state with a
/// retry button is rendered when the initial load fails.
///
/// ## Topics
/// ### View Components
/// - ``backendRow(_:)`` - Card row showing color dot, health badge, name, URL, active badge, and context menu
/// - ``healthBadge(_:)`` - Filled circle indicator colored by health status
/// - ``healthColor(_:)`` - Maps ``BackendConnection/HealthStatus`` cases to theme colors
///
/// ### Health Status Colors
/// - `.healthy` → `theme.success`
/// - `.degraded` → `theme.warning`
/// - `.unreachable` → `theme.error`
/// - `.unknown` → `theme.textTertiary`
///
/// ### Context Menu Actions
/// - **Activate** — sets the backend as active (hidden when already active)
/// - **Copy URL** — copies the backend URL to the clipboard
/// - **Remove** — permanently deletes the connection profile (destructive)
struct BackendConnectionsView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @State private var viewModel = BackendConnectionsViewModel()
    @State private var showAddBackend = false
    @State private var showSwitchBanner = false
    @State private var switchBannerText: String = ""

    var body: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacingMD) {
                ForEach(viewModel.backends) { backend in
                    backendRow(backend)
                }

                if let error = viewModel.loadError {
                    VStack(spacing: theme.spacingSM) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundStyle(theme.error)
                        Text(error)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await viewModel.loadBackends() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(theme.accent)
                    }
                    .padding(theme.spacingLG)
                }

                if viewModel.backends.isEmpty && !viewModel.isLoading && viewModel.loadError == nil {
                    EmptyEntityState(
                        entityType: .system,
                        title: "No Backends",
                        description: "Add a backend to connect to a remote ILS instance."
                    )
                }

                if viewModel.isLoading {
                    ProgressView()
                        .tint(theme.accent)
                        .padding(.vertical, theme.spacingLG)
                }
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.top, theme.spacingSM)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Backends")
        .inlineNavigationBarTitle()
        .toolbar {
            #if os(iOS)
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                NavigationLink {
                    BackendHealthDashboardView()
                } label: {
                    Image(systemName: "gauge")
                        .foregroundStyle(theme.accent)
                }
                Button {
                    showAddBackend = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(theme.accent)
                }
            }
            #else
            ToolbarItem(placement: .automatic) {
                NavigationLink {
                    BackendHealthDashboardView()
                } label: {
                    Image(systemName: "gauge")
                        .foregroundStyle(theme.accent)
                }
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    showAddBackend = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(theme.accent)
                }
            }
            #endif
        }
        .sheet(isPresented: $showAddBackend) {
            AddBackendView(viewModel: viewModel)
        }
        .task {
            await viewModel.loadBackends()
            // Trigger an immediate poll on appear without interfering with
            // the background polling task owned by AppState.handleScenePhase.
            await viewModel.pollNow()
        }
        .overlay(alignment: .top) {
            if showSwitchBanner {
                HStack(spacing: theme.spacingSM) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.success)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    Text("Switched to \(switchBannerText)")
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                }
                .padding(.horizontal, theme.spacingMD)
                .padding(.vertical, theme.spacingSM)
                .background(theme.success.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                .padding(.horizontal, theme.spacingMD)
                .padding(.top, theme.spacingSM)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityLabel("Switched to \(switchBannerText)")
            }
        }
        .onChange(of: viewModel.lastActivatedBackendName) { _, newValue in
            if let name = newValue {
                switchBannerText = name
                withAnimation(.easeInOut(duration: 0.3)) {
                    showSwitchBanner = true
                }
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSwitchBanner = false
                        }
                        viewModel.lastActivatedBackendName = nil
                    }
                }
            }
        }
    }

    // MARK: - Backend Row

    /// Card row for a single backend showing its color dot, health badge, name, URL,
    /// active indicator, and a context menu with activate/copy URL/remove actions.
    @ViewBuilder
    private func backendRow(_ backend: BackendConnection) -> some View {
        HStack(spacing: theme.spacingMD) {
            Circle()
                .fill(Color(hex: backend.colorHex))
                .frame(width: 16, height: 16)

            healthBadge(backend.healthStatus)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: theme.spacingSM) {
                    Text(backend.name)
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    if backend.id == viewModel.activeBackendId {
                        Text("Active")
                            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(theme.accent)
                            .clipShape(Capsule())
                    }
                }
                Text(verbatim: backend.url)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Menu {
                if backend.id != viewModel.activeBackendId {
                    Button {
                        Task { await viewModel.setActive(id: backend.id) }
                    } label: {
                        Label("Activate", systemImage: "checkmark.circle")
                    }
                }
                Button {
                    copyURL(backend.url)
                } label: {
                    Label("Copy URL", systemImage: "doc.on.doc")
                }
                Button(role: .destructive) {
                    Task { await viewModel.removeBackend(id: backend.id) }
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
        .accessibilityLabel("\(backend.name), \(backend.healthStatus.rawValue)")
    }

    /// Small filled circle indicator whose color reflects the backend's current health status.
    @ViewBuilder
    private func healthBadge(_ status: BackendConnection.HealthStatus) -> some View {
        Circle()
            .fill(healthColor(status))
            .frame(width: 12, height: 12)
    }

    /// Maps a ``BackendConnection/HealthStatus`` value to its corresponding theme color.
    ///
    /// - `.healthy` → `theme.success`
    /// - `.degraded` → `theme.warning`
    /// - `.unreachable` → `theme.error`
    /// - `.unknown` → `theme.textTertiary`
    private func healthColor(_ status: BackendConnection.HealthStatus) -> Color {
        switch status {
        case .healthy: return theme.success
        case .degraded: return theme.warning
        case .unreachable: return theme.error
        case .unknown: return theme.textTertiary
        }
    }

    // MARK: - Clipboard

    private func copyURL(_ url: String) {
        #if os(iOS)
        UIPasteboard.general.string = url
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
        #endif
        HapticManager.selection()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BackendConnectionsView()
    }
}
