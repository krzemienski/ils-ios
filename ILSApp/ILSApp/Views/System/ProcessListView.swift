import SwiftUI
import ILSShared

/// Process list with search and sort controls.
/// Embedded in SystemMonitorView below the charts.
struct ProcessListView: View {
    @Environment(\.theme) private var theme: any AppTheme
    @ObservedObject var viewModel: SystemMetricsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            // Header
            HStack {
                Text("Processes")
                    .font(.system(size: theme.fontBody, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)

                Spacer()

                // Sort toggle
                Picker("Sort", selection: $viewModel.processSortBy) {
                    ForEach(SystemMetricsViewModel.ProcessSortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
                .onChange(of: viewModel.processSortBy) { _, _ in
                    Task {
                        await viewModel.loadProcesses()
                    }
                }
            }

            // Search bar
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.textTertiary)
                TextField("Search processes", text: $viewModel.processSearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.fontBody))
                    .foregroundStyle(theme.textPrimary)

                if !viewModel.processSearchText.isEmpty {
                    Button {
                        viewModel.processSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }
            .padding(theme.spacingSM)
            .background(theme.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

            // Process list
            if viewModel.isLoadingProcesses && viewModel.processes.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(theme.entitySystem)
                    Spacer()
                }
                .padding(.vertical, theme.spacingMD)
            } else if viewModel.filteredProcesses.isEmpty {
                HStack {
                    Spacer()
                    Text("No processes found")
                        .font(.system(size: theme.fontCaption))
                        .foregroundStyle(theme.textTertiary)
                    Spacer()
                }
                .padding(.vertical, theme.spacingMD)
            } else {
                // Column headers
                HStack {
                    Text("Name")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("PID")
                        .frame(width: 50, alignment: .trailing)
                    Text("CPU")
                        .frame(width: 50, alignment: .trailing)
                    Text("MEM")
                        .frame(width: 55, alignment: .trailing)
                }
                .font(.system(size: theme.fontCaption, weight: .medium))
                .foregroundStyle(theme.textTertiary)
                .padding(.horizontal, theme.spacingXS)

                LazyVStack(spacing: 0) {
                    ForEach(viewModel.filteredProcesses.prefix(50), id: \.pid) { process in
                        processRow(process)
                    }
                }
            }
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
    }

    private func processRow(_ process: ProcessInfoResponse) -> some View {
        HStack {
            Text(process.name)
                .font(.system(size: theme.fontCaption, design: .monospaced))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(process.pid)")
                .font(.system(size: theme.fontCaption, design: .monospaced))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 50, alignment: .trailing)

            Text(String(format: "%.1f%%", process.cpuPercent))
                .font(.system(size: theme.fontCaption, design: .monospaced))
                .foregroundStyle(process.cpuPercent > 50 ? theme.warning : theme.textSecondary)
                .frame(width: 50, alignment: .trailing)

            Text(String(format: "%.0fM", process.memoryMB))
                .font(.system(size: theme.fontCaption, design: .monospaced))
                .foregroundStyle(process.memoryMB > 500 ? theme.warning : theme.textSecondary)
                .frame(width: 55, alignment: .trailing)
        }
        .padding(.horizontal, theme.spacingXS)
        .padding(.vertical, theme.spacingXS)
    }
}
