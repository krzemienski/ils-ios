import SwiftUI
import ILSShared

/// Process list with search and sort controls.
/// Embedded in SystemMonitorView below the charts.
struct ProcessListView: View {
    @ObservedObject var viewModel: SystemMetricsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: ILSTheme.spaceS) {
            // Header
            HStack {
                Text("Processes")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(ILSTheme.textPrimary)

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
            HStack(spacing: ILSTheme.spaceS) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(ILSTheme.textTertiary)
                TextField("Search processes", text: $viewModel.processSearchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(ILSTheme.textPrimary)

                if !viewModel.processSearchText.isEmpty {
                    Button {
                        viewModel.processSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ILSTheme.textTertiary)
                    }
                }
            }
            .padding(ILSTheme.spaceS)
            .background(ILSTheme.bg3)
            .clipShape(RoundedRectangle(cornerRadius: ILSTheme.radiusXS))

            // Process list
            if viewModel.isLoadingProcesses && viewModel.processes.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(EntityType.system.color)
                    Spacer()
                }
                .padding(.vertical, ILSTheme.spaceL)
            } else if viewModel.filteredProcesses.isEmpty {
                HStack {
                    Spacer()
                    Text("No processes found")
                        .font(.caption)
                        .foregroundColor(ILSTheme.textTertiary)
                    Spacer()
                }
                .padding(.vertical, ILSTheme.spaceL)
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
                .font(.caption2.weight(.medium))
                .foregroundColor(ILSTheme.textTertiary)
                .padding(.horizontal, ILSTheme.spaceXS)

                LazyVStack(spacing: 0) {
                    ForEach(viewModel.filteredProcesses.prefix(50), id: \.pid) { process in
                        processRow(process)
                    }
                }
            }
        }
        .padding(ILSTheme.spaceM)
        .background(ILSTheme.bg2)
        .clipShape(RoundedRectangle(cornerRadius: ILSTheme.radiusS))
    }

    private func processRow(_ process: ProcessInfoResponse) -> some View {
        HStack {
            Text(process.name)
                .font(.caption.monospacedDigit())
                .foregroundColor(ILSTheme.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(process.pid)")
                .font(.caption2.monospacedDigit())
                .foregroundColor(ILSTheme.textSecondary)
                .frame(width: 50, alignment: .trailing)

            Text(String(format: "%.1f%%", process.cpuPercent))
                .font(.caption.monospacedDigit())
                .foregroundColor(process.cpuPercent > 50 ? .orange : ILSTheme.textSecondary)
                .frame(width: 50, alignment: .trailing)

            Text(String(format: "%.0fM", process.memoryMB))
                .font(.caption.monospacedDigit())
                .foregroundColor(process.memoryMB > 500 ? .orange : ILSTheme.textSecondary)
                .frame(width: 55, alignment: .trailing)
        }
        .padding(.horizontal, ILSTheme.spaceXS)
        .padding(.vertical, ILSTheme.spaceXS)
    }
}
