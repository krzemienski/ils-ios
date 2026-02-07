import SwiftUI

struct LogViewerView: View {
    @State private var logs: [String] = []

    var body: some View {
        List {
            if logs.isEmpty {
                ContentUnavailableView("No Logs", systemImage: "doc.text", description: Text("App logs will appear here"))
            } else {
                ForEach(Array(logs.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(logColor(for: line))
                        .listRowBackground(Color.black)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("Logs")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        logs = await AppLogger.shared.recentLogs()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise").foregroundColor(.orange)
                }
            }
        }
        .task {
            logs = await AppLogger.shared.recentLogs()
        }
    }

    private func logColor(for line: String) -> Color {
        if line.contains("[ERROR]") { return .red }
        if line.contains("[WARN]") { return .orange }
        return .gray
    }
}
