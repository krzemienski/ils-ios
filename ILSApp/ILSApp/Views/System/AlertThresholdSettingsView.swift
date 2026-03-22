import SwiftUI
import UserNotifications

// MARK: - AlertThresholdSettingsView

/// Alert threshold configuration screen for system metric monitoring.
///
/// Provides four sections:
/// 1. **Presets** — picker that applies a named threshold configuration (Development Machine,
///    CI Server, Production Host, or Custom).
/// 2. **Per-metric cards** — CPU, Memory, Disk (slider + cooldown), and Network (connectivity
///    toggle + cooldown). Each card has an enabled toggle, threshold slider, condition label,
///    and cooldown picker.
/// 3. **Global cooldown** — apply a single cooldown duration to all metrics at once.
/// 4. **Test notification** — fire a sample notification to verify permission & delivery.
///
/// State is read from and persisted to ``AlertThresholdManager/shared``.
struct AlertThresholdSettingsView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    // MARK: - Preset State

    @State private var selectedPreset: AlertPreset? = nil
    /// Prevents metric onChange handlers from resetting selectedPreset during preset application.
    @State private var isApplyingPreset = false

    // MARK: - CPU

    @State private var cpuEnabled: Bool = false
    @State private var cpuThreshold: Double = 90
    @State private var cpuCooldown: TimeInterval = 300

    // MARK: - Memory

    @State private var memoryEnabled: Bool = false
    @State private var memoryThreshold: Double = 85
    @State private var memoryCooldown: TimeInterval = 300

    // MARK: - Disk

    @State private var diskEnabled: Bool = false
    @State private var diskThreshold: Double = 90
    @State private var diskCooldown: TimeInterval = 3600

    // MARK: - Network

    @State private var networkEnabled: Bool = false
    @State private var networkCooldown: TimeInterval = 60

    // MARK: - Global Cooldown

    @State private var globalCooldown: TimeInterval = 300

    // MARK: - Test Notification

    @State private var testNotificationSent: Bool = false

    // MARK: - Constants

    private let manager = AlertThresholdManager.shared

    private let cooldownOptions: [TimeInterval] = [60, 300, 900, 1800, 3600]

    private func cooldownLabel(_ seconds: TimeInterval) -> String {
        switch seconds {
        case 60: return "1 min"
        case 300: return "5 min"
        case 900: return "15 min"
        case 1800: return "30 min"
        case 3600: return "1 hr"
        default: return "\(Int(seconds / 60)) min"
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingMD) {
                presetsSection
                cpuCard
                memoryCard
                diskCard
                networkCard
                globalCooldownSection
                testNotificationSection
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingSM)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Alert Thresholds")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .onAppear {
            loadFromManager()
        }
        // Preset picker
        .onChange(of: selectedPreset) { _, newPreset in
            guard let preset = newPreset, !isApplyingPreset else { return }
            applyPreset(preset)
        }
        // CPU
        .onChange(of: cpuEnabled) { _, _ in
            guard !isApplyingPreset else { return }
            saveMetric(.cpu)
            selectedPreset = nil
        }
        .onChange(of: cpuThreshold) { _, _ in
            guard !isApplyingPreset else { return }
            saveMetric(.cpu)
            selectedPreset = nil
        }
        .onChange(of: cpuCooldown) { _, _ in
            guard !isApplyingPreset else { return }
            saveMetric(.cpu)
            selectedPreset = nil
        }
        // Memory
        .onChange(of: memoryEnabled) { _, _ in
            guard !isApplyingPreset else { return }
            saveMetric(.memory)
            selectedPreset = nil
        }
        .onChange(of: memoryThreshold) { _, _ in
            guard !isApplyingPreset else { return }
            saveMetric(.memory)
            selectedPreset = nil
        }
        .onChange(of: memoryCooldown) { _, _ in
            guard !isApplyingPreset else { return }
            saveMetric(.memory)
            selectedPreset = nil
        }
        // Disk
        .onChange(of: diskEnabled) { _, _ in
            guard !isApplyingPreset else { return }
            saveMetric(.disk)
            selectedPreset = nil
        }
        .onChange(of: diskThreshold) { _, _ in
            guard !isApplyingPreset else { return }
            saveMetric(.disk)
            selectedPreset = nil
        }
        .onChange(of: diskCooldown) { _, _ in
            guard !isApplyingPreset else { return }
            saveMetric(.disk)
            selectedPreset = nil
        }
        // Network
        .onChange(of: networkEnabled) { _, _ in
            guard !isApplyingPreset else { return }
            saveMetric(.network)
            selectedPreset = nil
        }
        .onChange(of: networkCooldown) { _, _ in
            guard !isApplyingPreset else { return }
            saveMetric(.network)
            selectedPreset = nil
        }
    }

    // MARK: - Preset Section

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Preset")

            VStack(alignment: .leading, spacing: theme.spacingSM) {
                HStack {
                    Text("Profile")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Picker("", selection: $selectedPreset) {
                        Text("Custom").tag(Optional<AlertPreset>.none)
                        ForEach(AlertPreset.allCases, id: \.self) { preset in
                            Text(preset.displayName).tag(Optional<AlertPreset>.some(preset))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(theme.accent)
                }

                if let preset = selectedPreset {
                    Text(preset.description)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                } else {
                    Text("Thresholds are configured individually below.")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    // MARK: - CPU Card

    private var cpuCard: some View {
        metricCard(
            title: "CPU",
            icon: "cpu",
            iconColor: theme.entitySystem,
            conditionPrefix: ">=",
            unit: "%",
            metricType: .cpu,
            enabled: $cpuEnabled,
            threshold: $cpuThreshold,
            cooldown: $cpuCooldown
        )
    }

    // MARK: - Memory Card

    private var memoryCard: some View {
        metricCard(
            title: "Memory",
            icon: "memorychip",
            iconColor: theme.entitySystem,
            conditionPrefix: ">=",
            unit: "%",
            metricType: .memory,
            enabled: $memoryEnabled,
            threshold: $memoryThreshold,
            cooldown: $memoryCooldown
        )
    }

    // MARK: - Disk Card

    private var diskCard: some View {
        metricCard(
            title: "Disk",
            icon: "internaldrive",
            iconColor: theme.accent,
            conditionPrefix: ">=",
            unit: "%",
            metricType: .disk,
            enabled: $diskEnabled,
            threshold: $diskThreshold,
            cooldown: $diskCooldown
        )
    }

    // MARK: - Network Card

    private var networkCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Network")

            VStack(spacing: 0) {
                HStack {
                    Label("Network Loss", systemImage: "wifi.slash")
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Toggle("", isOn: $networkEnabled)
                        .labelsHidden()
                        .tint(theme.accent)
                }
                .accessibilityLabel("Enable Network Loss alerts")
                .onChange(of: networkEnabled) {
                    HapticManager.selection()
                }

                if networkEnabled {
                    Divider().background(theme.bgTertiary).padding(.vertical, theme.spacingXS)

                    HStack(alignment: .top, spacing: theme.spacingSM) {
                        Image(systemName: "info.circle")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                        Text("Alerts when network connectivity is lost (connectivity = 0).")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                        Spacer()
                    }

                    Divider().background(theme.bgTertiary).padding(.vertical, theme.spacingXS)

                    HStack {
                        Text("Cooldown")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                        Spacer()
                        cooldownPicker(selection: $networkCooldown)
                    }
                    .accessibilityLabel("Network alert cooldown period")

                    Divider().background(theme.bgTertiary).padding(.vertical, theme.spacingXS)

                    // Snooze controls
                    snoozeRow(for: .network)
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    // MARK: - Global Cooldown Section

    private var globalCooldownSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Global Cooldown")

            VStack(spacing: theme.spacingSM) {
                HStack {
                    Text("Duration")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    cooldownPicker(selection: $globalCooldown)
                }

                Text("Apply this cooldown to all metrics at once.")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)

                Button {
                    applyGlobalCooldown()
                } label: {
                    Text("Apply to All Metrics")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, theme.spacingXS)
                }
                .buttonStyle(.plain)
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    // MARK: - Test Notification Section

    private var testNotificationSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Test")

            Button {
                sendTestNotification()
            } label: {
                HStack(spacing: theme.spacingSM) {
                    Image(systemName: testNotificationSent ? "checkmark.circle.fill" : "bell.badge")
                        .foregroundStyle(testNotificationSent ? theme.success : theme.accent)
                    Text(testNotificationSent ? "Notification Sent" : "Send Test Notification")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(testNotificationSent ? theme.success : theme.accent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacingXS)
            }
            .buttonStyle(.plain)
            .disabled(testNotificationSent)
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    // MARK: - Snooze Row

    /// Renders snooze controls for a given metric type.
    /// Shows active snooze expiry + "Clear" when snoozed; shows a "Snooze" menu otherwise.
    @ViewBuilder
    private func snoozeRow(for metricType: AlertMetricType) -> some View {
        if let threshold = manager.thresholds.first(where: { $0.metricType == metricType }) {
            if threshold.isSnoozed, let snoozedUntil = threshold.snoozedUntil {
                HStack {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.warning)
                    Text("Snoozed until \(snoozedUntil.formatted(.dateTime.hour().minute()))")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.warning)
                    Spacer()
                    Button("Clear") {
                        manager.clearSnooze(id: threshold.id)
                        HapticManager.selection()
                    }
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)
                    .buttonStyle(.plain)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "\(metricType.displayName) alerts snoozed until \(snoozedUntil.formatted(.dateTime.hour().minute())). Activate to clear snooze."
                )
            } else {
                HStack {
                    Text("Snooze Alerts")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    Menu {
                        ForEach(SnoozeDuration.allCases, id: \.self) { duration in
                            Button(duration.displayName) {
                                manager.snoozeThreshold(id: threshold.id, for: duration)
                                HapticManager.selection()
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Snooze")
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        }
                        .foregroundStyle(theme.accent)
                    }
                    .accessibilityLabel("Snooze \(metricType.displayName) alerts")
                }
            }
        }
    }

    // MARK: - Reusable Metric Card

    @ViewBuilder
    private func metricCard(
        title: String,
        icon: String,
        iconColor: Color,
        conditionPrefix: String,
        unit: String,
        metricType: AlertMetricType,
        enabled: Binding<Bool>,
        threshold: Binding<Double>,
        cooldown: Binding<TimeInterval>
    ) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel(title)

            VStack(spacing: 0) {
                // Enable toggle
                HStack {
                    Label(title, systemImage: icon)
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Toggle("", isOn: enabled)
                        .labelsHidden()
                        .tint(theme.accent)
                }
                .accessibilityLabel("Enable \(title) alerts")
                .onChange(of: enabled.wrappedValue) {
                    HapticManager.selection()
                }

                if enabled.wrappedValue {
                    Divider().background(theme.bgTertiary).padding(.vertical, theme.spacingXS)

                    // Threshold slider
                    VStack(alignment: .leading, spacing: theme.spacingXS) {
                        HStack {
                            Text("Threshold")
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)
                            Spacer()
                            Text("\(conditionPrefix) \(Int(threshold.wrappedValue))\(unit)")
                                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                                .foregroundStyle(iconColor)
                                .monospacedDigit()
                        }
                        Slider(value: threshold, in: 0...100, step: 1)
                            .tint(iconColor)
                            .accessibilityLabel(
                                "\(title) alert threshold: \(Int(threshold.wrappedValue)) percent"
                            )
                    }

                    Divider().background(theme.bgTertiary).padding(.vertical, theme.spacingXS)

                    // Cooldown picker
                    HStack {
                        Text("Cooldown")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                        Spacer()
                        cooldownPicker(selection: cooldown)
                    }
                    .accessibilityLabel("\(title) alert cooldown period")

                    Divider().background(theme.bgTertiary).padding(.vertical, theme.spacingXS)

                    // Snooze controls
                    snoozeRow(for: metricType)
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    // MARK: - Cooldown Picker

    @ViewBuilder
    private func cooldownPicker(selection: Binding<TimeInterval>) -> some View {
        Picker("", selection: selection) {
            ForEach(cooldownOptions, id: \.self) { option in
                Text(cooldownLabel(option)).tag(option)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .tint(theme.accent)
    }

    // MARK: - Section Label

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
            .kerning(1)
    }

    // MARK: - Data Loading

    private func loadFromManager() {
        for threshold in manager.thresholds {
            switch threshold.metricType {
            case .cpu:
                cpuEnabled = threshold.isEnabled
                cpuThreshold = threshold.thresholdValue
                cpuCooldown = closestCooldown(threshold.cooldownSeconds)
            case .memory:
                memoryEnabled = threshold.isEnabled
                memoryThreshold = threshold.thresholdValue
                memoryCooldown = closestCooldown(threshold.cooldownSeconds)
            case .disk:
                diskEnabled = threshold.isEnabled
                diskThreshold = threshold.thresholdValue
                diskCooldown = closestCooldown(threshold.cooldownSeconds)
            case .network:
                networkEnabled = threshold.isEnabled
                networkCooldown = closestCooldown(threshold.cooldownSeconds)
            }
        }
        detectCurrentPreset()
    }

    private func closestCooldown(_ seconds: TimeInterval) -> TimeInterval {
        cooldownOptions.min(by: { abs($0 - seconds) < abs($1 - seconds) }) ?? 300
    }

    // MARK: - Preset Detection

    private func detectCurrentPreset() {
        let thresholds = manager.thresholds
        guard !thresholds.isEmpty else {
            selectedPreset = nil
            return
        }
        for preset in AlertPreset.allCases {
            if presetMatches(preset, thresholds: thresholds) {
                selectedPreset = preset
                return
            }
        }
        selectedPreset = nil
    }

    private func presetMatches(_ preset: AlertPreset, thresholds: [AlertThreshold]) -> Bool {
        let presetThresholds = preset.makeThresholds()
        guard thresholds.count == presetThresholds.count else { return false }
        for pt in presetThresholds {
            guard let t = thresholds.first(where: { $0.metricType == pt.metricType }) else {
                return false
            }
            guard abs(t.thresholdValue - pt.thresholdValue) < 0.01,
                  t.condition == pt.condition,
                  abs(t.cooldownSeconds - pt.cooldownSeconds) < 0.01,
                  t.isEnabled else {
                return false
            }
        }
        return true
    }

    // MARK: - Preset Application

    private func applyPreset(_ preset: AlertPreset) {
        isApplyingPreset = true
        manager.applyPreset(preset)
        loadFromManager()
        // Reset flag after SwiftUI has processed onChange from loadFromManager updates
        Task { @MainActor in
            isApplyingPreset = false
        }
        HapticManager.selection()
    }

    // MARK: - Metric Save

    private func saveMetric(_ type: AlertMetricType) {
        switch type {
        case .cpu:
            updateOrAdd(
                type: .cpu, value: cpuThreshold, condition: .greaterThan,
                cooldown: cpuCooldown, enabled: cpuEnabled
            )
        case .memory:
            updateOrAdd(
                type: .memory, value: memoryThreshold, condition: .greaterThan,
                cooldown: memoryCooldown, enabled: memoryEnabled
            )
        case .disk:
            updateOrAdd(
                type: .disk, value: diskThreshold, condition: .greaterThan,
                cooldown: diskCooldown, enabled: diskEnabled
            )
        case .network:
            updateOrAdd(
                type: .network, value: 0.0, condition: .equalTo,
                cooldown: networkCooldown, enabled: networkEnabled
            )
        }
    }

    private func updateOrAdd(
        type: AlertMetricType,
        value: Double,
        condition: AlertCondition,
        cooldown: TimeInterval,
        enabled: Bool
    ) {
        if let existing = manager.thresholds.first(where: { $0.metricType == type }) {
            let updated = AlertThreshold(
                id: existing.id,
                metricType: type,
                thresholdValue: value,
                condition: condition,
                cooldownSeconds: cooldown,
                isEnabled: enabled,
                snoozedUntil: existing.snoozedUntil
            )
            manager.updateThreshold(updated)
        } else {
            manager.addThreshold(AlertThreshold(
                metricType: type,
                thresholdValue: value,
                condition: condition,
                cooldownSeconds: cooldown,
                isEnabled: enabled
            ))
        }
    }

    // MARK: - Global Cooldown

    private func applyGlobalCooldown() {
        cpuCooldown = globalCooldown
        memoryCooldown = globalCooldown
        diskCooldown = globalCooldown
        networkCooldown = globalCooldown
        HapticManager.selection()
    }

    // MARK: - Test Notification

    private func sendTestNotification() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "ILS Alert Test"
            content.body = "Your system monitoring alert thresholds are configured and working correctly."
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "ils.alert.test.\(Date().timeIntervalSince1970)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            )

            UNUserNotificationCenter.current().add(request) { _ in
                Task { @MainActor in
                    self.testNotificationSent = true
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    self.testNotificationSent = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AlertThresholdSettingsView()
            .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
    }
}
