import SwiftUI

// MARK: - Spec 023: Configuration Automation Scripts

struct AutomationScriptsView: View {
    @State private var scripts: [AutomationScript] = AutomationScript.samples

    var body: some View {
        List {
            if scripts.isEmpty {
                EmptyStateView(
                    title: "No Automation Scripts",
                    systemImage: "gearshape.2",
                    description: "Create scripts to automate configuration changes"
                )
            } else {
                ForEach(scripts) { script in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(script.name)
                                .font(ILSTheme.headlineFont)
                            Spacer()
                            StatusBadge(
                                text: script.isEnabled ? "Active" : "Inactive",
                                color: script.isEnabled ? ILSTheme.success : ILSTheme.tertiaryText
                            )
                        }

                        Text(script.description)
                            .font(ILSTheme.captionFont)
                            .foregroundColor(ILSTheme.secondaryText)
                            .lineLimit(2)

                        HStack(spacing: 8) {
                            Label(script.trigger, systemImage: "bolt.fill")
                                .font(ILSTheme.captionFont)
                                .foregroundColor(ILSTheme.accent)

                            Spacer()

                            if let lastRun = script.lastRun {
                                Text(lastRun, style: .relative)
                                    .font(ILSTheme.captionFont)
                                    .foregroundColor(ILSTheme.tertiaryText)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                Text("Automation scripts run configuration changes based on triggers like project switching, time of day, or network changes.")
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.secondaryText)
            }
        }
        .darkListStyle()
        .navigationTitle("Automation")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AutomationScript: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let trigger: String
    let isEnabled: Bool
    let lastRun: Date?

    static let samples: [AutomationScript] = [
        AutomationScript(
            name: "Work Hours Config",
            description: "Switch to work MCP servers during business hours",
            trigger: "Schedule: 9am-5pm",
            isEnabled: true,
            lastRun: Date().addingTimeInterval(-3600)
        ),
        AutomationScript(
            name: "Project Auto-Setup",
            description: "Configure project-specific MCP servers when switching projects",
            trigger: "On project change",
            isEnabled: true,
            lastRun: Date().addingTimeInterval(-7200)
        ),
        AutomationScript(
            name: "Nightly Cleanup",
            description: "Remove stale sessions and clear caches overnight",
            trigger: "Schedule: 2am daily",
            isEnabled: false,
            lastRun: nil
        )
    ]
}
