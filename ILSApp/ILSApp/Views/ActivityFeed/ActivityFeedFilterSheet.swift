import SwiftUI
import ILSShared

/// A bottom sheet for configuring the activity feed filter.
///
/// Presents three sections: **Event Types** (one toggle per ``ActivityEventType`` plus
/// a "show/hide" toggle for each type from the configured set), **Minimum Severity**
/// (a segmented picker), and **Session** (an optional session ID text field). The sheet
/// is non-destructive: changes only take effect when the user taps **Apply**.
///
/// ## Topics
/// ### Inputs
/// - ``filter`` - The currently active filter to pre-populate controls
/// - ``hiddenEventTypes`` - Event types currently hidden from the feed
/// - ``onApply`` - Called with the new filter and hidden-type set when the user confirms
///
/// ### Sections
/// - ``eventTypesSection`` - Toggles enabling or disabling each event type
/// - ``severitySection`` - Segmented control for minimum severity
/// - ``sessionSection`` - Text field for filtering to a single session ID
struct ActivityFeedFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// The filter state to pre-populate the sheet's controls.
    let filter: ActivityFeedFilter
    /// Event types currently suppressed from the feed.
    let hiddenEventTypes: Set<ActivityEventType>
    /// Callback invoked when the user taps Apply; passes the new filter and hidden-type set.
    let onApply: (ActivityFeedFilter, Set<ActivityEventType>) -> Void

    // MARK: - Local Edit State

    /// Mutable selection of event types to show (nil = all visible).
    @State private var selectedEventTypes: Set<ActivityEventType> = []
    /// Whether each type is visible (true = shown, false = hidden).
    @State private var typeVisibility: [ActivityEventType: Bool] = {
        Dictionary(uniqueKeysWithValues: ActivityEventType.allCases.map { ($0, true) })
    }()
    /// Selected minimum severity (nil = any).
    @State private var selectedSeverity: ActivityEventSeverity? = nil
    /// Session ID text field content.
    @State private var sessionIdText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                eventTypesSection
                severitySection
                sessionSection
            }
            .navigationTitle("Filter Activity")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.impact(.light)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        HapticManager.impact(.medium)
                        applyFilter()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                #if os(iOS)
                ToolbarItem(placement: .bottomBar) {
                    Button("Reset") {
                        HapticManager.impact(.light)
                        resetToDefaults()
                    }
                    .foregroundStyle(theme.error)
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("Reset") {
                        HapticManager.impact(.light)
                        resetToDefaults()
                    }
                    .foregroundStyle(theme.error)
                }
                #endif
            }
            .onAppear {
                populateFromFilter()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Event Types Section

    @ViewBuilder
    private var eventTypesSection: some View {
        Section {
            ForEach(ActivityEventType.allCases, id: \.self) { type in
                Toggle(isOn: Binding(
                    get: { typeVisibility[type] ?? true },
                    set: { typeVisibility[type] = $0 }
                )) {
                    Label(displayName(for: type), systemImage: icon(for: type))
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                }
                .tint(theme.accent)
            }
        } header: {
            Text("Event Types")
        } footer: {
            Text("Toggle event types to show or hide them from the feed.")
        }
    }

    // MARK: - Severity Section

    @ViewBuilder
    private var severitySection: some View {
        Section {
            Picker("Minimum Severity", selection: $selectedSeverity) {
                Text("Any").tag(ActivityEventSeverity?.none)
                ForEach(ActivityEventSeverity.allCases, id: \.self) { sev in
                    Text(displayName(for: sev)).tag(ActivityEventSeverity?.some(sev))
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Minimum Severity")
        } footer: {
            Text("Show only events at or above the selected severity level.")
        }
    }

    // MARK: - Session Section

    @ViewBuilder
    private var sessionSection: some View {
        Section {
            HStack {
                Image(systemName: "terminal.fill")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                TextField("Session ID (optional)", text: $sessionIdText)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !sessionIdText.isEmpty {
                    Button {
                        sessionIdText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.textTertiary)
                    }
                    .accessibilityLabel("Clear session ID")
                }
            }
        } header: {
            Text("Session")
        } footer: {
            Text("Limit the feed to events from a single session.")
        }
    }

    // MARK: - Actions

    /// Build the new filter from local state and invoke the apply callback.
    private func applyFilter() {
        // Hidden types = types the user has toggled off
        let newHidden = Set(ActivityEventType.allCases.filter { !(typeVisibility[$0] ?? true) })

        let newFilter = ActivityFeedFilter(
            eventTypes: nil, // visibility is handled via hiddenEventTypes
            sessionId: sessionIdText.trimmingCharacters(in: .whitespaces).isEmpty
                ? nil
                : sessionIdText.trimmingCharacters(in: .whitespaces),
            projectName: filter.projectName,
            severity: selectedSeverity,
            since: filter.since,
            limit: filter.limit
        )

        onApply(newFilter, newHidden)
    }

    /// Pre-populate controls from the provided filter and hidden-type set.
    private func populateFromFilter() {
        // Visibility = inverse of hidden
        for type in ActivityEventType.allCases {
            typeVisibility[type] = !hiddenEventTypes.contains(type)
        }
        selectedSeverity = filter.severity
        sessionIdText = filter.sessionId ?? ""
    }

    /// Reset all controls to their default (show-all) state.
    private func resetToDefaults() {
        for type in ActivityEventType.allCases {
            typeVisibility[type] = true
        }
        selectedSeverity = nil
        sessionIdText = ""
    }

    // MARK: - Display Helpers

    /// Human-readable label for an event type.
    private func displayName(for type: ActivityEventType) -> String {
        switch type {
        case .messageSent:      return "Message Sent"
        case .messageReceived:  return "Message Received"
        case .permissionRequest: return "Permission Request"
        case .error:            return "Error"
        case .completion:       return "Completion"
        case .fileChange:       return "File Change"
        case .systemEvent:      return "System Event"
        }
    }

    /// SF Symbol icon name for an event type (replicates ``ActivityEventRow`` mapping).
    private func icon(for type: ActivityEventType) -> String {
        switch type {
        case .messageSent:      return "message.fill"
        case .messageReceived:  return "message.fill"
        case .permissionRequest: return "exclamationmark.triangle.fill"
        case .error:            return "xmark.circle.fill"
        case .completion:       return "checkmark.circle.fill"
        case .fileChange:       return "doc.fill"
        case .systemEvent:      return "bolt.fill"
        }
    }

    /// Human-readable label for a severity level.
    private func displayName(for severity: ActivityEventSeverity) -> String {
        switch severity {
        case .info:    return "Info"
        case .warning: return "Warning"
        case .error:   return "Error"
        }
    }
}
