import SwiftUI
import ILSShared

// MARK: - Offline Cache Settings Section

/// Settings section for configuring offline caching behavior.
///
/// Displays current cache storage usage in MB, a master enable toggle,
/// per-type content toggles (sessions, messages, projects, skills, MCP
/// servers, plugins), a stepper for the maximum cached-session count
/// (10–200, step 10), and a destructive Clear Cache button.
struct OfflineCacheSettingsView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @ObservedObject private var settings = OfflineCacheSettings.shared

    @State private var cacheSizeBytes: Int64 = 0
    @State private var isClearingCache: Bool = false
    @State private var showClearConfirmation: Bool = false
    @State private var troubledSessions: [(session: ChatSession, syncMetadata: SyncMetadata)] = []
    @State private var selectedConflictSession: (local: ChatSession, server: ChatSession, fields: [ConflictField])? = nil
    @State private var showConflictSheet: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Offline Cache")

            storageSection

            cacheTypesSection

            syncStatusSection

            capacitySection

            clearCacheSection

            Text("Cached data is available when your device is offline or the server is unreachable.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .task {
            cacheSizeBytes = await CacheService.shared.cacheStorageBytes()
            refreshTroubledSessions()
        }
        .onReceive(NotificationCenter.default.publisher(for: .syncStatusDidChange)) { _ in
            refreshTroubledSessions()
        }
        .sheet(isPresented: $showConflictSheet) {
            if let conflict = selectedConflictSession {
                NavigationStack {
                    ConflictResolutionSheet(
                        localSession: conflict.local,
                        serverSession: conflict.server,
                        conflictFields: conflict.fields
                    )
                }
            }
        }
    }

    // MARK: - Storage Section

    private var storageSection: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Cache Storage", systemImage: "internaldrive")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Text(formattedCacheSize)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .accessibilityLabel("Cache size: \(formattedCacheSize)")
            }
            .padding(theme.spacingMD)

            Divider().background(theme.bgTertiary)

            Toggle(isOn: $settings.isCacheEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Offline Cache")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Text("Store data locally for offline access")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .tint(theme.accent)
            .padding(theme.spacingMD)
            .accessibilityLabel("Enable offline cache")
        }
        .modifier(GlassCard())
    }

    // MARK: - Cache Content Toggles

    private var cacheTypesSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Cache Content")

            VStack(spacing: 0) {
                cacheTypeToggle("Sessions", icon: "bubble.left.and.bubble.right", binding: $settings.sessionsEnabled)
                Divider().background(theme.bgTertiary)
                cacheTypeToggle("Messages", icon: "text.bubble", binding: $settings.messagesEnabled)
                Divider().background(theme.bgTertiary)
                cacheTypeToggle("Projects", icon: "folder", binding: $settings.projectsEnabled)
                Divider().background(theme.bgTertiary)
                cacheTypeToggle("Skills", icon: "hammer", binding: $settings.skillsEnabled)
                Divider().background(theme.bgTertiary)
                cacheTypeToggle("MCP Servers", icon: "server.rack", binding: $settings.mcpServersEnabled)
                Divider().background(theme.bgTertiary)
                cacheTypeToggle("Plugins", icon: "puzzlepiece.extension", binding: $settings.pluginsEnabled)
            }
            .modifier(GlassCard())
        }
        .disabled(!settings.isCacheEnabled)
        .opacity(settings.isCacheEnabled ? 1 : 0.5)
    }

    // MARK: - Capacity Section

    private var capacitySection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Capacity")

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Max Cached Sessions")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                        Text("\(settings.maxSessions) sessions")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                    Stepper(
                        "",
                        value: $settings.maxSessions,
                        in: 10...200,
                        step: 10
                    )
                    .labelsHidden()
                    .accessibilityLabel("Max cached sessions: \(settings.maxSessions)")
                }
                .padding(theme.spacingMD)
            }
            .modifier(GlassCard())

            Text("Limits how many sessions are stored locally. Range: 10–200.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .disabled(!settings.isCacheEnabled)
        .opacity(settings.isCacheEnabled ? 1 : 0.5)
    }

    // MARK: - Clear Cache Section

    private var clearCacheSection: some View {
        VStack(spacing: 0) {
            Button {
                showClearConfirmation = true
            } label: {
                HStack {
                    Label("Clear Cache", systemImage: "trash")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.error)
                    Spacer()
                    if isClearingCache {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .padding(theme.spacingMD)
            }
            .disabled(isClearingCache)
            .accessibilityLabel("Clear offline cache")
        }
        .modifier(GlassCard())
        .alert("Clear Offline Cache?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear Cache", role: .destructive) {
                Task { await performClearCache() }
            }
        } message: {
            Text("This removes all locally cached data. Content will be re-downloaded when you're back online.")
        }
    }

    // MARK: - Sync Status Section

    private var syncStatusSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Sync Status")

            SyncStatusOverview()

            VStack(spacing: 0) {
                Toggle(isOn: $settings.autoResolveConflicts) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-resolve Conflicts")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                        Text("Use last-write-wins by timestamp")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                .tint(theme.accent)
                .padding(theme.spacingMD)
                .accessibilityLabel("Auto-resolve sync conflicts")
            }
            .modifier(GlassCard())

            if !troubledSessions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(troubledSessions.enumerated()), id: \.element.session.id) { index, entry in
                        if index > 0 {
                            Divider().background(theme.bgTertiary)
                        }
                        troubledSessionRow(session: entry.session, metadata: entry.syncMetadata)
                    }
                }
                .modifier(GlassCard())
            }
        }
        .disabled(!settings.isCacheEnabled)
        .opacity(settings.isCacheEnabled ? 1 : 0.5)
    }

    @ViewBuilder
    private func troubledSessionRow(session: ChatSession, metadata: SyncMetadata) -> some View {
        HStack(spacing: theme.spacingSM) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name ?? "Untitled Session")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                Text(metadata.syncStatus.displayName)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(metadata.syncStatus == .conflict ? theme.warning : theme.error)
            }

            Spacer()

            if metadata.syncStatus == .conflict {
                Button {
                    presentConflictSheet(for: session, metadata: metadata)
                } label: {
                    Text("Resolve")
                        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, theme.spacingSM)
                        .padding(.vertical, theme.spacingXS)
                        .background(Capsule().fill(theme.accent.opacity(0.12)))
                }
                .accessibilityLabel("Resolve conflict for \(session.name ?? "session")")
            } else if metadata.syncStatus == .failed {
                Button {
                    Task {
                        await SyncCoordinator.shared.retryFailed(sessionId: session.id.uuidString)
                    }
                } label: {
                    Text("Retry")
                        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.error)
                        .padding(.horizontal, theme.spacingSM)
                        .padding(.vertical, theme.spacingXS)
                        .background(Capsule().fill(theme.error.opacity(0.12)))
                }
                .accessibilityLabel("Retry sync for \(session.name ?? "session")")
            }
        }
        .padding(theme.spacingMD)
    }

    // MARK: - Private Helpers

    private var formattedCacheSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: cacheSizeBytes)
    }

    private func performClearCache() async {
        isClearingCache = true
        await CacheService.shared.clearAll()
        cacheSizeBytes = await CacheService.shared.cacheStorageBytes()
        isClearingCache = false
    }

    private func refreshTroubledSessions() {
        Task {
            do {
                let allSessions = try await LocalDatabase.shared.fetchSessionsWithSyncStatus()
                let filtered = allSessions.filter { entry in
                    entry.syncMetadata.syncStatus == .conflict || entry.syncMetadata.syncStatus == .failed
                }
                await MainActor.run {
                    troubledSessions = filtered
                }
            } catch {
                await MainActor.run {
                    troubledSessions = []
                }
            }
        }
    }

    private func presentConflictSheet(for session: ChatSession, metadata: SyncMetadata) {
        // Decode the server session from conflict data
        guard let conflictData = metadata.conflictData else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let serverSession = try? decoder.decode(ChatSession.self, from: conflictData) else { return }

        // Detect conflicting fields
        var fields: [ConflictField] = []
        if session.name != serverSession.name { fields.append(.name) }
        if session.status != serverSession.status { fields.append(.status) }
        if session.messageCount != serverSession.messageCount { fields.append(.messageCount) }

        selectedConflictSession = (local: session, server: serverSession, fields: fields)
        showConflictSheet = true
    }

    @ViewBuilder
    private func cacheTypeToggle(
        _ title: String,
        icon: String,
        binding: Binding<Bool>
    ) -> some View {
        Toggle(isOn: binding) {
            Label(title, systemImage: icon)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
        }
        .tint(theme.accent)
        .padding(theme.spacingMD)
        .accessibilityLabel("Cache \(title)")
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
            .kerning(1)
    }
}

#Preview {
    ScrollView {
        OfflineCacheSettingsView()
            .padding()
    }
    #if canImport(UIKit)
    .background(Color(.systemBackground))
    #else
    .background(Color(.windowBackgroundColor))
    #endif
}
