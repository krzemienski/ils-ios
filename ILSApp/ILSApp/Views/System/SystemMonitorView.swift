import SwiftUI
import Charts
import ILSShared

/// Real-time system resource monitor backed by a persistent WebSocket connection.
///
/// Renders live Charts framework graphs for CPU usage, dual-series network throughput
/// (in/out as separate ``LineMark`` series), plus ``ProgressRing`` widgets for Memory and Disk.
/// A load-average row (1m / 5m / 15m) and a ``ProcessListView`` complete the dashboard.
///
/// ## WebSocket Lifecycle
/// The connection to ``MetricsWebSocketClient`` is opened in `onAppear` and closed in
/// `onDisappear`, keeping metrics streaming only while the view is visible.  If the server
/// URL has changed since the last appearance the old client is replaced before reconnecting.
/// Scene-phase transitions (`active` → background/inactive) pause the pulsing live indicator
/// without dropping the underlying socket.
///
/// ## Topics
/// ### State
/// - ``viewModel`` - Observable view model that owns the WebSocket client and metric history
/// - ``livePulse`` - Drives the pulsing animation on the live indicator dot
///
/// ### View Components
/// - ``networkChart`` - Dual-series Charts view showing bytes-in and bytes-out over time
/// - ``liveIndicator`` - Toolbar dot that pulses when connected; respects Reduce Motion
///
/// ### Helpers
/// - ``formatBytes(_:)`` - Converts a raw `UInt64` byte count to a human-readable string (B / KB / MB / GB)
struct SystemMonitorView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot
    /// Used by ``liveIndicator`` to disable the repeating pulse animation for users who prefer reduced motion.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    /// View model that manages the ``MetricsWebSocketClient`` and exposes aggregated metric values.
    @State private var viewModel = SystemMetricsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingMD) {
                // CPU Chart - full width
                MetricChart(
                    title: "CPU Usage",
                    data: viewModel.metricsClient.cpuHistory,
                    color: theme.entitySystem,
                    unit: "%",
                    currentValue: String(format: "%.1f%%", viewModel.cpuPercentage)
                )

                // Load Average
                if !viewModel.loadAverage.isEmpty {
                    HStack(spacing: theme.spacingMD) {
                        ForEach(Array(zip(["1m", "5m", "15m"], viewModel.loadAverage)), id: \.0) { label, value in
                            VStack(spacing: 4) {
                                Text(String(format: "%.2f", value))
                                    .font(.system(size: theme.fontBody, weight: .bold, design: theme.fontDesign))
                                    .foregroundStyle(theme.textPrimary)
                                Text(label)
                                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                    .foregroundStyle(theme.textTertiary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(theme.spacingMD)
                    .modifier(GlassCard())
                }

                // Memory & Disk - 2-column grid
                HStack(spacing: theme.spacingMD) {
                    // Memory
                    VStack(spacing: theme.spacingSM) {
                        ProgressRing(
                            progress: viewModel.memoryPercentage / 100,
                            gradient: LinearGradient(
                                colors: [theme.entitySystem, theme.entitySystem.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            title: "Memory",
                            subtitle: String(
                                format: "%.1f / %.1f GB",
                                viewModel.memoryUsedGB,
                                viewModel.memoryTotalGB
                            )
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(theme.spacingMD)
                    .modifier(GlassCard())

                    // Disk
                    VStack(spacing: theme.spacingSM) {
                        ProgressRing(
                            progress: viewModel.diskPercentage / 100,
                            gradient: LinearGradient(
                                colors: [theme.accent, theme.accent.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            title: "Disk",
                            subtitle: String(
                                format: "%.0f / %.0f GB",
                                viewModel.diskUsedGB,
                                viewModel.diskTotalGB
                            )
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(theme.spacingMD)
                    .modifier(GlassCard())
                }

                // Network Chart - dual line
                networkChart

                // Process List
                ProcessListView(viewModel: viewModel)

                // File Browser link
                NavigationLink {
                    FileBrowserView()
                } label: {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundStyle(theme.entitySystem)
                        Text("File Browser")
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .padding(theme.spacingMD)
                    .modifier(GlassCard())
                }
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.bottom, theme.spacingLG)
        }
        .background(theme.bgPrimary)
        .navigationTitle("System")
        .inlineNavigationBarTitle()
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                liveIndicator
            }
            #else
            ToolbarItem(placement: .automatic) {
                liveIndicator
            }
            #endif
        }
        .onAppear {
            viewModel.updateBaseURL(appState.serverURL)
            viewModel.connect()
        }
        .onDisappear {
            viewModel.disconnect()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                viewModel.connect()  // BATT-02: Resume WebSocket on foreground
                if viewModel.isConnected { livePulse = true }
            case .background:
                viewModel.disconnect()  // BATT-02: Suspend WebSocket on background
                livePulse = false
            default:
                livePulse = false
            }
        }
        .onChange(of: appState.serverURL) { _, newURL in
            viewModel.updateBaseURL(newURL)
            viewModel.connect()
        }
    }

    // MARK: - Network Chart

    /// Dual-series line chart displaying inbound and outbound network throughput over time.
    ///
    /// Renders two ``LineMark`` series drawn from ``MetricsWebSocketClient/networkInHistory``
    /// and ``MetricsWebSocketClient/networkOutHistory``.  When both histories are empty a
    /// placeholder rectangle is shown while the WebSocket connection delivers the first sample.
    /// The chart is exposed to VoiceOver as a single accessibility element with a combined label.
    private var networkChart: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack {
                Text("Network")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Spacer()

                HStack(spacing: theme.spacingMD) {
                    Label(formatBytes(viewModel.networkBytesIn) + "/s", systemImage: "arrow.down")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.entitySystem)

                    Label(formatBytes(viewModel.networkBytesOut) + "/s", systemImage: "arrow.up")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.accent)
                }
            }

            let inData = viewModel.metricsClient.networkInHistory
            let outData = viewModel.metricsClient.networkOutHistory

            if inData.isEmpty && outData.isEmpty {
                Rectangle()
                    .fill(theme.bgTertiary)
                    .frame(height: 100)
                    .overlay {
                        Text("Waiting for data...")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            } else {
                Chart {
                    ForEach(inData) { point in
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("In", point.value),
                            series: .value("Direction", "In")
                        )
                        .foregroundStyle(theme.entitySystem)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }

                    ForEach(outData) { point in
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Out", point.value),
                            series: .value("Direction", "Out")
                        )
                        .foregroundStyle(theme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(theme.textTertiary)
                    }
                }
                .frame(height: 100)
            }
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Network usage chart, \(formatBytes(viewModel.networkBytesIn)) per second download, \(formatBytes(viewModel.networkBytesOut)) per second upload")
    }

    // MARK: - Live Indicator

    /// Controls the repeating scale animation on the connection-status dot in the toolbar.
    /// Set to `true` on `onAppear` and reset to `false` when the scene moves out of the active phase.
    @State private var livePulse = false

    /// Toolbar badge showing the current WebSocket connection status.
    ///
    /// Displays a green pulsing dot labeled "Live" when connected, or a static red dot
    /// labeled "Offline" when disconnected.  The repeating scale animation is suppressed when
    /// `accessibilityReduceMotion` is enabled, replacing it with a `.default` (instant) animation.
    private var liveIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(viewModel.isConnected ? theme.success : theme.error)
                .frame(width: 8, height: 8)
                .scaleEffect(livePulse && viewModel.isConnected ? 1.3 : 1.0)
                .animation(
                    reduceMotion ? nil : (viewModel.isConnected
                        ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                        : .default),
                    value: livePulse
                )
                .onAppear { livePulse = true }

            Text(viewModel.isConnected ? "Live" : "Offline")
                .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(viewModel.isConnected ? theme.success : theme.error)
        }
    }

    // MARK: - Helpers

    /// Converts a raw byte count into a human-readable string with the appropriate unit.
    ///
    /// Returns values in B, KB, MB, or GB depending on magnitude, using one decimal place
    /// for MB and GB and no decimal for KB.
    ///
    /// - Parameter bytes: The number of bytes to format.
    /// - Returns: A localized string such as `"1.4 MB"` or `"512 KB"`.
    private func formatBytes(_ bytes: UInt64) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        let gb = mb / 1024

        if gb >= 1 { return String(format: "%.1f GB", gb) }
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        if kb >= 1 { return String(format: "%.0f KB", kb) }
        return "\(bytes) B"
    }
}

#Preview {
    NavigationStack {
        SystemMonitorView()
            .environment(AppState())
            .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
    }
}
