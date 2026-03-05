import SwiftUI

/// Displays cache memory usage statistics and management controls.
///
/// Shows real-time cache size, entry counts, and hit rates from MemoryManager.
/// Provides configurable cache size limit (25MB, 50MB, 75MB, 100MB) persisted
/// via AppStorage. Displays visual progress bar for cache utilization and Clear
/// Cache button for manual eviction. Automatically refreshes on appearance.
///
/// ## Topics
/// ### State
/// - ``stats`` - Current cache statistics from MemoryManager
/// - ``lastUpdated`` - Timestamp of last statistics refresh
/// - ``isClearing`` - Whether a cache clear operation is in progress
/// - ``cacheSizeMB`` - User-configured cache size limit in megabytes
///
/// ### Actions
/// - ``loadStats()`` - Fetch latest cache statistics from MemoryManager
/// - ``clearCache()`` - Trigger manual cache eviction via MemoryManager
struct MemoryUsageView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @EnvironmentObject private var appState: AppState

    /// Current cache statistics loaded from MemoryManager.
    @State private var stats: CacheStats?

    /// Timestamp when statistics were last refreshed.
    @State private var lastUpdated: Date?

    /// Whether a cache clear operation is currently in progress.
    @State private var isClearing: Bool = false

    /// Configured cache size limit in megabytes, persisted via AppStorage.
    @AppStorage("cacheSizeMB") private var cacheSizeMB: Int = AppConstants.defaultCacheSizeMB

    /// Available cache size options in megabytes.
    private let availableCacheSizes = [25, 50, 75, 100]

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            // Section header
            HStack {
                Text("Memory Usage")
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .textCase(.uppercase)
                    .kerning(1)

                Spacer()

                if let lastUpdated {
                    CacheStatusView(lastUpdated: lastUpdated)
                }
            }

            // Cache size configuration
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                Text("CACHE LIMIT")
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .textCase(.uppercase)
                    .kerning(1)

                VStack(spacing: 0) {
                    HStack {
                        Text("Maximum Cache Size")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)

                        Spacer()

                        Picker("Cache Size", selection: $cacheSizeMB) {
                            ForEach(availableCacheSizes, id: \.self) { size in
                                Text("\(size) MB").tag(size)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .tint(theme.accent)
                    }
                    .padding(theme.spacingMD)
                }
                .modifier(GlassCard())

                Text("Larger cache sizes improve performance but consume more memory. Cache is automatically cleared on memory warnings.")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }

            // Statistics section header
            Text("CURRENT USAGE")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .textCase(.uppercase)
                .kerning(1)

            // Content card
            VStack(spacing: theme.spacingMD) {
                // Cache size with progress bar
                if let stats {
                    VStack(alignment: .leading, spacing: theme.spacingSM) {
                        HStack {
                            Text("Cache Size")
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)

                            Spacer()

                            Text("\(stats.currentSizeFormatted) / \(stats.maxSizeFormatted)")
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)
                                .monospacedDigit()
                        }

                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background track
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(theme.bgSecondary)
                                    .frame(height: 8)

                                // Progress fill
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(progressColor(for: stats.utilizationPercent))
                                    .frame(
                                        width: geometry.size.width * (stats.utilizationPercent / 100.0),
                                        height: 8
                                    )
                                    .animation(.easeInOut(duration: 0.3), value: stats.utilizationPercent)
                            }
                        }
                        .frame(height: 8)

                        Text("\(Int(stats.utilizationPercent))% utilized")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }

                    Divider()
                        .background(theme.border)

                    // Entry count
                    HStack {
                        Text("Cached Entries")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)

                        Spacer()

                        Text("\(stats.entryCount)")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                            .monospacedDigit()
                    }

                    // Hit rate (if available)
                    if let hitRate = stats.hitRate {
                        Divider()
                            .background(theme.border)

                        HStack {
                            Text("Hit Rate")
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)

                            Spacer()

                            Text("\(Int(hitRate * 100))%")
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)
                                .monospacedDigit()
                        }
                    }

                    Divider()
                        .background(theme.border)

                    // Clear Cache button
                    Button(action: { Task { await clearCache() } }) {
                        HStack(spacing: theme.spacingSM) {
                            if isClearing {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "trash")
                                    .font(.system(size: theme.fontBody))
                            }

                            Text(isClearing ? "Clearing..." : "Clear Cache")
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        }
                        .foregroundStyle(isClearing ? theme.textTertiary : theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, theme.spacingSM)
                    }
                    .disabled(isClearing || stats.entryCount == 0)
                    .buttonStyle(.plain)

                } else {
                    // Loading state
                    HStack {
                        ProgressView()
                            .progressViewStyle(.circular)

                        Text("Loading cache statistics...")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingMD)
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
        .task {
            await loadStats()
        }
        .onChange(of: cacheSizeMB) { _, newSize in
            Task {
                await MemoryManager.shared.configureCacheSize(
                    newSize * 1024 * 1024,
                    connectionManager: appState.connectionManager
                )
                await loadStats() // Refresh stats to show new limit
            }
            #if os(iOS)
            HapticManager.selection()
            #endif
        }
    }

    // MARK: - Actions

    /// Load cache statistics from MemoryManager.
    private func loadStats() async {
        stats = await MemoryManager.shared.getTotalMemoryUsage(
            from: appState.connectionManager
        )
        lastUpdated = Date()
    }

    /// Clear all caches via MemoryManager and reload statistics.
    private func clearCache() async {
        isClearing = true

        #if os(iOS)
        HapticManager.impact(.medium)
        #endif

        await MemoryManager.shared.handleMemoryWarning(
            connectionManager: appState.connectionManager
        )

        // Reload stats after clearing
        await loadStats()

        isClearing = false

        #if os(iOS)
        HapticManager.notification(.success)
        #endif
    }

    // MARK: - Helpers

    /// Determine progress bar color based on cache utilization.
    ///
    /// - Parameter utilizationPercent: Cache utilization percentage (0-100)
    /// - Returns: Color for the progress bar (green < 60%, yellow < 80%, red >= 80%)
    private func progressColor(for utilizationPercent: Double) -> Color {
        switch utilizationPercent {
        case ..<60:
            return Color.green
        case ..<80:
            return Color.yellow
        default:
            return Color.red
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        MemoryUsageView()
    }
    .padding()
    .background(Color(.systemBackground))
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
