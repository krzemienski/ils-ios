import SwiftUI
import Charts
import ILSShared

struct SystemMonitorView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: SystemMetricsViewModel

    init() {
        // Will be re-initialized with correct URL in .onAppear
        _viewModel = StateObject(wrappedValue: SystemMetricsViewModel())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ILSTheme.spaceL) {
                // CPU Chart - full width
                MetricChart(
                    title: "CPU Usage",
                    data: viewModel.metricsClient.cpuHistory,
                    color: EntityType.system.color,
                    unit: "%",
                    currentValue: String(format: "%.1f%%", viewModel.cpuPercentage)
                )

                // Load Average
                if !viewModel.loadAverage.isEmpty {
                    HStack(spacing: ILSTheme.spaceM) {
                        ForEach(Array(zip(["1m", "5m", "15m"], viewModel.loadAverage)), id: \.0) { label, value in
                            VStack(spacing: 4) {
                                Text(String(format: "%.2f", value))
                                    .font(.subheadline.monospacedDigit().bold())
                                    .foregroundColor(ILSTheme.textPrimary)
                                Text(label)
                                    .font(.caption2)
                                    .foregroundColor(ILSTheme.textTertiary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(ILSTheme.spaceM)
                    .background(ILSTheme.bg2)
                    .clipShape(RoundedRectangle(cornerRadius: ILSTheme.radiusS))
                }

                // Memory & Disk - 2-column grid
                HStack(spacing: ILSTheme.spaceM) {
                    // Memory
                    VStack(spacing: ILSTheme.spaceS) {
                        ProgressRing(
                            progress: viewModel.memoryPercentage / 100,
                            title: "Memory",
                            subtitle: String(
                                format: "%.1f / %.1f GB",
                                viewModel.memoryUsedGB,
                                viewModel.memoryTotalGB
                            )
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(ILSTheme.spaceM)
                    .background(ILSTheme.bg2)
                    .clipShape(RoundedRectangle(cornerRadius: ILSTheme.radiusS))

                    // Disk
                    VStack(spacing: ILSTheme.spaceS) {
                        ProgressRing(
                            progress: viewModel.diskPercentage / 100,
                            gradient: LinearGradient(
                                colors: [Color.orange, Color.orange.opacity(0.6)],
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
                    .padding(ILSTheme.spaceM)
                    .background(ILSTheme.bg2)
                    .clipShape(RoundedRectangle(cornerRadius: ILSTheme.radiusS))
                }

                // Network Chart - dual line
                networkChart

                // Process List
                ProcessListView(viewModel: viewModel)

                // File Browser link
                NavigationLink {
                    FileBrowserView(baseURL: appState.serverURL)
                } label: {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(EntityType.system.color)
                        Text("File Browser")
                            .foregroundColor(ILSTheme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(ILSTheme.textTertiary)
                    }
                    .padding(ILSTheme.spaceM)
                    .background(ILSTheme.bg2)
                    .clipShape(RoundedRectangle(cornerRadius: ILSTheme.radiusS))
                }
            }
            .padding(.horizontal, ILSTheme.spaceL)
            .padding(.bottom, ILSTheme.space2XL)
        }
        .background(ILSTheme.bg0)
        .navigationTitle("System")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                liveIndicator
            }
        }
        .onAppear {
            viewModel.metricsClient = MetricsWebSocketClient(baseURL: appState.serverURL)
            viewModel.connect()
            Task {
                await viewModel.loadProcesses()
            }
        }
        .onDisappear {
            viewModel.disconnect()
        }
    }

    // MARK: - Network Chart

    private var networkChart: some View {
        VStack(alignment: .leading, spacing: ILSTheme.spaceS) {
            HStack {
                Text("Network")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(ILSTheme.textPrimary)

                Spacer()

                HStack(spacing: ILSTheme.spaceM) {
                    Label(formatBytes(viewModel.networkBytesIn) + "/s", systemImage: "arrow.down")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(EntityType.system.color)

                    Label(formatBytes(viewModel.networkBytesOut) + "/s", systemImage: "arrow.up")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.blue)
                }
            }

            let inData = viewModel.metricsClient.networkInHistory
            let outData = viewModel.metricsClient.networkOutHistory

            if inData.isEmpty && outData.isEmpty {
                Rectangle()
                    .fill(ILSTheme.bg3)
                    .frame(height: 100)
                    .overlay {
                        Text("Waiting for data...")
                            .font(.caption)
                            .foregroundColor(ILSTheme.textTertiary)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: ILSTheme.radiusXS))
            } else {
                Chart {
                    ForEach(inData) { point in
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("In", point.value),
                            series: .value("Direction", "In")
                        )
                        .foregroundStyle(EntityType.system.color)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }

                    ForEach(outData) { point in
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Out", point.value),
                            series: .value("Direction", "Out")
                        )
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(ILSTheme.textTertiary)
                    }
                }
                .frame(height: 100)
            }
        }
        .padding(ILSTheme.spaceM)
        .background(ILSTheme.bg2)
        .clipShape(RoundedRectangle(cornerRadius: ILSTheme.radiusS))
    }

    // MARK: - Live Indicator

    @State private var livePulse = false

    private var liveIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(viewModel.isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
                .scaleEffect(livePulse && viewModel.isConnected ? 1.3 : 1.0)
                .animation(
                    viewModel.isConnected
                        ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                        : .default,
                    value: livePulse
                )
                .onAppear { livePulse = true }

            Text(viewModel.isConnected ? "Live" : "Offline")
                .font(.caption.weight(.medium))
                .foregroundColor(viewModel.isConnected ? .green : .red)
        }
    }

    // MARK: - Helpers

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
            .environmentObject(AppState())
    }
}
