import SwiftUI
import ILSShared

/// Process list with search and sort controls.
/// Embedded in SystemMonitorView below the charts.
struct ProcessListView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Bindable var viewModel: SystemMetricsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            // Header
            HStack {
                Text("Processes")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Spacer()

                // Sort toggle
                HStack(spacing: 0) {
                    ForEach(SystemMetricsViewModel.ProcessSortOption.allCases, id: \.self) { option in
                        Button {
                            viewModel.processSortBy = option
                            Task { await viewModel.loadProcesses() }
                        } label: {
                            Text(option.rawValue)
                                .font(.system(size: theme.fontCaption, weight: viewModel.processSortBy == option ? .semibold : .regular, design: theme.fontDesign))
                                .foregroundStyle(viewModel.processSortBy == option ? theme.textPrimary : theme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(viewModel.processSortBy == option ? theme.accent.opacity(0.15) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(theme.bgTertiary)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                .frame(width: 150)
            }

            // Search bar
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.textTertiary)
                TextField("Search processes", text: $viewModel.processSearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
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
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
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
                .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
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
            // Process classification badge
            if let badge = classifyProcess(process.name) {
                Circle()
                    .fill(badge.color)
                    .frame(width: 6, height: 6)
            }

            Text(process.name)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(process.pid)")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 50, alignment: .trailing)

            Text(String(format: "%.1f%%", process.cpuPercent))
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(process.cpuPercent > 50 ? theme.warning : theme.textSecondary)
                .frame(width: 50, alignment: .trailing)

            Text(String(format: "%.0fM", process.memoryMB))
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(process.memoryMB > 500 ? theme.warning : theme.textSecondary)
                .frame(width: 55, alignment: .trailing)
        }
        .padding(.horizontal, theme.spacingXS)
        .padding(.vertical, theme.spacingXS)
    }

    // MARK: - Process Classification

    private struct ProcessBadge {
        let label: String
        let color: Color
    }

    private func classifyProcess(_ name: String) -> ProcessBadge? {
        let lowered = name.lowercased()
        if lowered.contains("claude") {
            return ProcessBadge(label: "Claude", color: theme.entitySession)
        }
        if lowered.contains("ilsbackend") || lowered == "ilsbackend" {
            return ProcessBadge(label: "ILS", color: theme.success)
        }
        if lowered.contains("swift") || lowered.contains("vapor") || lowered.contains("swiftc") {
            return ProcessBadge(label: "Swift", color: theme.warning)
        }
        if lowered.contains("node") || lowered.contains("npm") || lowered.contains("npx") {
            return ProcessBadge(label: "Node", color: theme.entitySkill)
        }
        return nil
    }
}
