import SwiftUI

struct LogViewerView: View {
    @Environment(\.theme) private var theme: any AppTheme
    @State private var logs: [String] = []

    var body: some View {
        ScrollView {
            if logs.isEmpty {
                ContentUnavailableView("No Logs", systemImage: "doc.text", description: Text("App logs will appear here"))
                    .foregroundStyle(theme.textSecondary)
            } else {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(logs.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(logColor(for: line))
                            .padding(.horizontal, theme.spacingSM)
                            .padding(.vertical, 2)
                    }
                }
                .padding(.vertical, theme.spacingSM)
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle("Logs")
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
            logs = await AppLogger.shared.recentLogs()
        }
    }

    private var refreshButton: some View {
        Button {
            Task {
                logs = await AppLogger.shared.recentLogs()
            }
        } label: {
            Image(systemName: "arrow.clockwise")
                .foregroundStyle(theme.accent)
        }
        .accessibilityLabel("Refresh logs")
    }

    private func logColor(for line: String) -> Color {
        if line.contains("[ERROR]") { return theme.error }
        if line.contains("[WARN]") { return theme.warning }
        return theme.textSecondary
    }
}
