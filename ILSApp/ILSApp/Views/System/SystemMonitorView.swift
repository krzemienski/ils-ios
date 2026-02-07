import SwiftUI

struct SystemMonitorView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 40)

                Image(systemName: "gauge.with.dots.needle.33percent")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [EntityType.system.color, EntityType.system.color.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("System Monitor")
                    .font(.title2.bold())
                    .foregroundColor(ILSTheme.textPrimary)

                Text("Real-time host metrics, process monitoring,\nand file browsing coming soon.")
                    .font(.subheadline)
                    .foregroundColor(ILSTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .background(ILSTheme.background)
        .navigationTitle("System")
    }
}

#Preview {
    NavigationStack {
        SystemMonitorView()
            .environmentObject(AppState())
    }
}
