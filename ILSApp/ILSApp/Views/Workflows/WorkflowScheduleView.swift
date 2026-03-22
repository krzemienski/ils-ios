import SwiftUI
import ILSShared

/// View for managing automated workflow execution schedules.
///
/// Provides UI for creating, editing, and managing cron-based workflow schedules.
/// Displays schedule status, next trigger time, and supports common presets for easy
/// configuration. Follows SettingsView patterns with sectioned layout and glass card
/// UI components.
///
/// ## Topics
/// ### State
/// - ``workflow`` - The workflow to schedule
/// - ``viewModel`` - View model managing schedule data and API calls
/// - ``schedule`` - Current schedule configuration
/// - ``sheets`` - Sheet presentation state
///
/// ### View Components
/// - ``mainContent`` - Top-level layout container
/// - ``scheduleStatusSection`` - Current schedule status and info
/// - ``scheduleConfigSection`` - Schedule configuration form
/// - ``presetSection`` - Common cron presets
///
/// ### Actions
/// - ``saveSchedule()`` - Save the current schedule configuration
/// - ``deleteSchedule()`` - Delete the existing schedule
/// - ``loadSchedule()`` - Load the current schedule from API
struct WorkflowScheduleView: View {
    /// The workflow to schedule.
    let workflow: Workflow
    /// Optional closure invoked when the user taps the back button.
    var onBack: (() -> Void)? = nil

    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss

    /// View model managing schedule state and API calls.
    @State private var viewModel: WorkflowViewModel
    /// Whether a schedule exists for this workflow.
    @State private var hasSchedule = false
    /// The current schedule configuration being edited.
    @State private var schedule: WorkflowSchedule?
    /// Whether the schedule is enabled.
    @State private var isEnabled = false
    /// The selected cron expression.
    @State private var cronExpression = ""
    /// The selected timezone (optional).
    @State private var timezone = ""
    /// Custom cron input mode.
    @State private var showCustomCron = false

    // MARK: - Grouped State

    /// Sheet and alert presentation state.
    struct SheetState {
        var showDeleteConfirmation = false
        var showSaveSuccess = false
        var showError = false
        var errorMessage = ""
    }

    /// State controlling sheet and alert presentation.
    @State private var sheets = SheetState()

    init(workflow: Workflow, onBack: (() -> Void)? = nil) {
        self.workflow = workflow
        self.onBack = onBack
        _viewModel = State(wrappedValue: WorkflowViewModel())
    }

    // MARK: - Body

    var body: some View {
        mainContent
            .background(theme.bgPrimary)
            .navigationTitle("Schedule Workflow")
            .inlineNavigationBarTitle()
            .toolbar { toolbarContent }
            .task {
                await loadSchedule()
            }
            .alert("Delete Schedule", isPresented: $sheets.showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteSchedule()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this schedule? The workflow will no longer run automatically.")
            }
            .alert("Schedule Saved", isPresented: $sheets.showSaveSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your workflow schedule has been saved successfully.")
            }
            .alert("Error", isPresented: $sheets.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(sheets.errorMessage)
            }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingLG) {
                workflowInfoSection

                if hasSchedule {
                    scheduleStatusSection
                }

                scheduleConfigSection

                if !showCustomCron {
                    presetSection
                }

                advancedSection
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingSM)
        }
    }

    // MARK: - Workflow Info Section

    private var workflowInfoSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("Workflow")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .textCase(.uppercase)
                .kerning(1)

            HStack(spacing: theme.spacingMD) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 20))
                    .foregroundStyle(theme.accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text(workflow.name)
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)

                    if let description = workflow.description, !description.isEmpty {
                        Text(description)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    // MARK: - Schedule Status Section

    private var scheduleStatusSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("Current Schedule")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .textCase(.uppercase)
                .kerning(1)

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Circle()
                                .fill(isEnabled ? theme.success : theme.textTertiary)
                                .frame(width: 8, height: 8)

                            Text(isEnabled ? "Enabled" : "Disabled")
                                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)
                        }

                        if let schedule = schedule {
                            Text(schedule.frequencyDescription)
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)
                        }
                    }

                    Spacer()
                }
                .padding(theme.spacingMD)

                if let schedule = schedule, let nextTrigger = schedule.nextTriggerAt, isEnabled {
                    Divider()

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Next Run")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)

                            Text(formattedDate(nextTrigger))
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)
                        }

                        Spacer()

                        if schedule.isDueSoon {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.badge.exclamationmark")
                                    .font(.system(size: theme.fontCaption))
                                Text("Soon")
                                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                            }
                            .foregroundStyle(theme.warning)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.warning.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .padding(theme.spacingMD)
                }

                if let schedule = schedule, let lastTriggered = schedule.lastTriggeredAt {
                    Divider()

                    HStack {
                        Text("Last Run")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)

                        Spacer()

                        Text(formattedRelativeTime(lastTriggered))
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                    }
                    .padding(theme.spacingMD)
                }
            }
            .modifier(GlassCard())
        }
    }

    // MARK: - Schedule Config Section

    private var scheduleConfigSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("Schedule Configuration")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .textCase(.uppercase)
                .kerning(1)

            VStack(spacing: 0) {
                // Enable/Disable Toggle
                HStack {
                    Text("Enable Schedule")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)

                    Spacer()

                    Toggle("", isOn: $isEnabled)
                        .labelsHidden()
                        .tint(theme.accent)
                }
                .padding(theme.spacingMD)
                .onChange(of: isEnabled) {
                    #if os(iOS)
                    HapticManager.selection()
                    #endif
                }

                if showCustomCron {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cron Expression")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)

                        TextField("0 0 * * *", text: $cronExpression)
                            .font(.system(size: theme.fontBody, design: .monospaced))
                            .textFieldStyle(.plain)
                            .padding(theme.spacingSM)
                            .background(theme.bgSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Text("Format: minute hour day month weekday")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .padding(theme.spacingMD)
                }
            }
            .modifier(GlassCard())

            if !showCustomCron {
                Text("Select a preset below or use custom cron expression.")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
        }
    }

    // MARK: - Preset Section

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("Common Schedules")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .textCase(.uppercase)
                .kerning(1)

            VStack(spacing: theme.spacingSM) {
                ForEach(WorkflowSchedule.Preset.allCases, id: \.self) { preset in
                    presetButton(preset)
                }
            }
        }
    }

    private func presetButton(_ preset: WorkflowSchedule.Preset) -> some View {
        Button {
            #if os(iOS)
            HapticManager.impact(.light)
            #endif
            cronExpression = preset.rawValue
            showCustomCron = false
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.description)
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)

                    Text(preset.rawValue)
                        .font(.system(size: theme.fontCaption, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer()

                if cronExpression == preset.rawValue {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.accent)
                        .font(.system(size: 20))
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(cronExpression == preset.rawValue ? theme.accent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("Advanced")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .textCase(.uppercase)
                .kerning(1)

            VStack(spacing: 0) {
                Button {
                    #if os(iOS)
                    HapticManager.impact(.light)
                    #endif
                    showCustomCron.toggle()
                    if !showCustomCron && cronExpression.isEmpty {
                        cronExpression = WorkflowSchedule.Preset.daily.rawValue
                    }
                } label: {
                    HStack {
                        Image(systemName: "terminal")
                            .foregroundStyle(theme.accent)

                        Text("Custom Cron Expression")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)

                        Spacer()

                        Image(systemName: showCustomCron ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(showCustomCron ? theme.accent : theme.textTertiary)
                    }
                    .padding(theme.spacingMD)
                }
                .buttonStyle(.plain)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Timezone (Optional)")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)

                    TextField("UTC", text: $timezone)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .textFieldStyle(.plain)
                        .padding(theme.spacingSM)
                        .background(theme.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text("Leave empty to use UTC. Format: America/New_York")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
                .padding(theme.spacingMD)
            }
            .modifier(GlassCard())
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            if let onBack {
                Button {
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(theme.accent)
                }
            }
        }

        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: theme.spacingMD) {
                if hasSchedule {
                    Button {
                        sheets.showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(theme.error)
                    }
                }

                Button {
                    Task {
                        await saveSchedule()
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Save")
                            .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                            .foregroundStyle(theme.accent)
                    }
                }
                .disabled(cronExpression.isEmpty || viewModel.isLoading)
            }
        }
    }

    // MARK: - Actions

    private func loadSchedule() async {
        await viewModel.loadSchedule(workflowId: workflow.id)

        if let schedule = viewModel.currentSchedule {
            self.schedule = schedule
            self.hasSchedule = true
            self.isEnabled = schedule.enabled
            self.cronExpression = schedule.cron
            self.timezone = schedule.timezone ?? ""

            // Check if it's a custom cron expression
            let isPreset = WorkflowSchedule.Preset.allCases.contains { $0.rawValue == schedule.cron }
            self.showCustomCron = !isPreset
        } else {
            // No schedule exists, set defaults
            self.hasSchedule = false
            self.isEnabled = true
            self.cronExpression = WorkflowSchedule.Preset.daily.rawValue
            self.timezone = ""
            self.showCustomCron = false
        }
    }

    private func saveSchedule() async {
        guard !cronExpression.isEmpty else {
            sheets.errorMessage = "Please enter a valid cron expression"
            sheets.showError = true
            return
        }

        #if os(iOS)
        HapticManager.impact(.medium)
        #endif

        let timezoneValue = timezone.isEmpty ? nil : timezone

        if hasSchedule {
            await viewModel.updateSchedule(
                workflowId: workflow.id,
                cron: cronExpression,
                enabled: isEnabled,
                timezone: timezoneValue
            )
        } else {
            await viewModel.createSchedule(
                workflowId: workflow.id,
                cron: cronExpression,
                enabled: isEnabled,
                timezone: timezoneValue
            )
        }

        if let error = viewModel.error {
            sheets.errorMessage = error.localizedDescription
            sheets.showError = true
        } else {
            sheets.showSaveSuccess = true
            await loadSchedule()
        }
    }

    private func deleteSchedule() async {
        #if os(iOS)
        HapticManager.impact(.medium)
        #endif

        await viewModel.deleteSchedule(workflowId: workflow.id)

        if let error = viewModel.error {
            sheets.errorMessage = error.localizedDescription
            sheets.showError = true
        } else {
            hasSchedule = false
            schedule = nil
            cronExpression = WorkflowSchedule.Preset.daily.rawValue
            isEnabled = true
            showCustomCron = false
        }
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formattedRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
