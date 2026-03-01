import SwiftUI

/// Backend health dashboard showing all connected backend instances with status indicators.
///
/// Displays a 2-column grid of backend health cards with large colored health circles,
/// backend name, URL, status text, and last-checked relative time.
///
/// - Note: Full implementation provided in subtask-3-4.
struct BackendHealthDashboardView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        ProgressView()
            .tint(theme.accent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.bgPrimary)
            .navigationTitle("Health Dashboard")
            .inlineNavigationBarTitle()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BackendHealthDashboardView()
    }
}
