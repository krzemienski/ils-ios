import SwiftUI

/// Sheet for configuring consumption alerts including burn rate, daily limits,
/// and exhaustion warnings.
///
/// Provides toggle-based enable/disable plus three sliders for fine-grained
/// control over when the user receives consumption notifications.
/// All values are persisted to ``UserDefaults`` via the view model.
struct ConsumptionAlertSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot
    var viewModel: ConsumptionDashboardViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Consumption Alerts") {
                    Toggle("Enable Alerts", isOn: Binding(
                        get: { viewModel.consumptionAlertsEnabled },
                        set: { viewModel.consumptionAlertsEnabled = $0 }
                    ))
                    .tint(theme.accent)

                    if viewModel.consumptionAlertsEnabled {
                        burnRateSlider
                        dailyLimitSlider
                        exhaustionWarningSlider
                    }
                }

                Section("How Projections Work") {
                    Text(
                        "Burn rate measures your average messages per hour over a rolling window. " +
                        "The daily consumption limit triggers an alert when your total messages for the day exceed the threshold. " +
                        "Exhaustion warning uses the current burn rate to project when your remaining quota will be depleted, " +
                        "alerting you when the projected time falls below your chosen hours. " +
                        "Alerts fire once per threshold crossing and reset automatically."
                    )
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                }
            }
            .navigationTitle("Alert Settings")
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Burn Rate Slider

    private var burnRateSlider: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack {
                Text("Burn Rate Warning")
                Spacer()
                Text("\(Int(viewModel.burnRateWarningThreshold)) msgs/hr")
                    .foregroundStyle(theme.textSecondary)
            }
            Slider(
                value: Binding(
                    get: { viewModel.burnRateWarningThreshold },
                    set: { viewModel.burnRateWarningThreshold = $0 }
                ),
                in: 1...20,
                step: 1
            )
            .tint(theme.accent)
            Text("Alert when your message rate exceeds this threshold.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
    }

    // MARK: - Daily Consumption Limit Slider

    private var dailyLimitSlider: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack {
                Text("Daily Consumption Limit")
                Spacer()
                Text("\(viewModel.dailyConsumptionLimit) messages")
                    .foregroundStyle(theme.textSecondary)
            }
            Slider(
                value: Binding(
                    get: { Double(viewModel.dailyConsumptionLimit) },
                    set: { viewModel.dailyConsumptionLimit = Int($0) }
                ),
                in: 10...200,
                step: 10
            )
            .tint(theme.accent)
            Text("Alert when your daily message count reaches this limit.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
    }

    // MARK: - Exhaustion Warning Slider

    private var exhaustionWarningSlider: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack {
                Text("Exhaustion Warning")
                Spacer()
                Text("\(viewModel.exhaustionWarningHours) \(viewModel.exhaustionWarningHours == 1 ? "hour" : "hours") remaining")
                    .foregroundStyle(theme.textSecondary)
            }
            Slider(
                value: Binding(
                    get: { Double(viewModel.exhaustionWarningHours) },
                    set: { viewModel.exhaustionWarningHours = Int($0) }
                ),
                in: 1...4,
                step: 1
            )
            .tint(theme.accent)
            Text("Alert when projected quota exhaustion is within this time.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
    }
}
