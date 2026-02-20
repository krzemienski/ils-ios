import SwiftUI

struct LogViewerView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    private struct LogLine: Identifiable {
        let id: Int
        let text: String
    }

    @State private var logs: [LogLine] = []

    var body: some View {
        ScrollView {
            if logs.isEmpty {
                ContentUnavailableView("No Logs", systemImage: "doc.text", description: Text("App logs will appear here"))
                    .foregroundStyle(theme.textSecondary)
            } else {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(logs) { line in
                        Text(line.text)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(logColor(for: line.text))
                            .padding(.horizontal, theme.spacingSM)
                            .padding(.vertical, 2)
                    }
                }
                .padding(.vertical, theme.spacingSM)
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle("Logs")
        .inlineNavigationBarTitle()
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
            let rawLogs = await AppLogger.shared.recentLogs()
            logs = rawLogs.enumerated().map { LogLine(id: $0.offset, text: $0.element) }
        }
    }

    private var refreshButton: some View {
        Button {
            Task {
                let rawLogs = await AppLogger.shared.recentLogs()
                logs = rawLogs.enumerated().map { LogLine(id: $0.offset, text: $0.element) }
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
