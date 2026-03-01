import SwiftUI
import ILSShared

// MARK: - Log Level Filter

private enum LogLevelFilter: String, CaseIterable {
    case all = "All"
    case error = "Error"
    case warn = "Warn"
    case info = "Info"
}

// MARK: - MCP Logs View

struct MCPLogsView: View {
    let server: MCPServer
    var viewModel: MCPViewModel

    @Environment(\.theme) private var theme: ThemeSnapshot

    @State private var logs: [MCPLogEntry] = []
    @State private var isLoading = false
    @State private var selectedLevel: LogLevelFilter = .all

    private var filteredLogs: [MCPLogEntry] {
        switch selectedLevel {
        case .all:
            return logs
        case .error:
            return logs.filter { $0.level.lowercased() == "error" }
        case .warn:
            return logs.filter { ["warn", "warning"].contains($0.level.lowercased()) }
        case .info:
            return logs.filter { $0.level.lowercased() == "info" }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            levelFilterPicker
            logContent
        }
        .background(theme.bgPrimary)
        .navigationTitle("\(server.name) Logs")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                refreshButton
            }
            #else
            ToolbarItem(placement: .automatic) {
                refreshButton
            }
            #endif
        }
        .task {
            await loadLogs()
        }
    }

    // MARK: - Subviews

    private var levelFilterPicker: some View {
        Picker("Log Level", selection: $selectedLevel) {
            ForEach(LogLevelFilter.allCases, id: \.self) { level in
                Text(level.rawValue).tag(level)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, theme.spacingMD)
        .padding(.vertical, theme.spacingSM)
    }

    @ViewBuilder
    private var logContent: some View {
        ScrollView {
            if isLoading {
                VStack(spacing: theme.spacingMD) {
                    ProgressView()
                        .tint(theme.accent)
                    Text("Loading logs…")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }
                .padding(theme.spacingMD)
            } else if filteredLogs.isEmpty {
                ContentUnavailableView(
                    "No Logs",
                    systemImage: "doc.text",
                    description: Text(
                        logs.isEmpty
                            ? "No log entries available for \(server.name)"
                            : "No \(selectedLevel.rawValue.lowercased()) entries found"
                    )
                )
                .foregroundStyle(theme.textSecondary)
            } else {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(filteredLogs.enumerated()), id: \.offset) { _, entry in
                        logRow(entry)
                    }
                }
                .padding(.vertical, theme.spacingSM)
            }
        }
    }

    private func logRow(_ entry: MCPLogEntry) -> some View {
        HStack(alignment: .top, spacing: theme.spacingSM) {
            Text(levelBadge(for: entry.level))
                .font(.system(size: theme.fontCaption, weight: .semibold, design: .monospaced))
                .foregroundStyle(logColor(for: entry.level))
                .frame(width: 38, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.message)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Text(entry.timestamp)
                    .font(.system(size: theme.fontCaption - 1, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, 3)
    }

    private var refreshButton: some View {
        Button {
            Task { await loadLogs() }
        } label: {
            Image(systemName: "arrow.clockwise")
                .foregroundStyle(theme.accent)
        }
        .accessibilityLabel("Refresh logs")
        .disabled(isLoading)
    }

    // MARK: - Helpers

    private func loadLogs() async {
        isLoading = true
        logs = await viewModel.fetchLogs(for: server)
        isLoading = false
    }

    private func logColor(for level: String) -> Color {
        switch level.lowercased() {
        case "error": return theme.error
        case "warn", "warning": return theme.warning
        default: return theme.textSecondary
        }
    }

    private func levelBadge(for level: String) -> String {
        switch level.lowercased() {
        case "error": return "ERR"
        case "warn", "warning": return "WRN"
        default: return "INF"
        }
    }
}
