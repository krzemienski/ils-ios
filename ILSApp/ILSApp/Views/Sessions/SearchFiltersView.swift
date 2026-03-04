import SwiftUI
import ILSShared

/// Filter sheet for cross-session message search.
///
/// Presents controls for narrowing search results by date range, message author role,
/// and project name. The caller provides the currently-active ``SearchFilters`` value
/// (pre-populated in the controls on appear) and an ``onApply`` callback that receives
/// the new ``SearchFilters`` when the user confirms.
///
/// The sheet is organised into three `List` sections:
/// - **Date Range** — Optional start/end date pickers with inline clear buttons.
/// - **Author** — Segmented-style role picker for "Any", "User", and "Assistant".
/// - **Project** — Free-text field to filter results by project name.
///
/// A **Reset All Filters** button is shown whenever at least one filter is active.
///
/// ## Topics
/// ### Inputs
/// - ``currentFilters`` - The active filters pre-populated on appear
/// - ``onApply`` - Callback invoked with the new ``SearchFilters`` on confirm
struct SearchFiltersView: View {

    // MARK: - Inputs

    /// The active filters to pre-populate the controls.
    let currentFilters: SearchFilters
    /// Callback receiving the confirmed ``SearchFilters`` value on Apply.
    let onApply: (SearchFilters) -> Void

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot

    // MARK: - Local Filter State

    @State private var dateFrom: Date?
    @State private var dateTo: Date?
    @State private var projectName: String = ""
    @State private var selectedRole: RoleFilter = .any

    // MARK: - Role Filter Enum

    /// Segmented role options mapped to the API `role` query parameter.
    private enum RoleFilter: String, CaseIterable, Hashable {
        case any       = "Any"
        case user      = "User"
        case assistant = "Assistant"

        /// The raw API role string, or `nil` for "Any".
        var apiValue: String? {
            switch self {
            case .any:       return nil
            case .user:      return "user"
            case .assistant: return "assistant"
            }
        }

        /// Initialise from the optional API role string stored in ``SearchFilters``.
        init(from role: String?) {
            switch role {
            case "user":      self = .user
            case "assistant": self = .assistant
            default:          self = .any
            }
        }
    }

    // MARK: - Computed

    private var hasActiveFilters: Bool {
        dateFrom != nil || dateTo != nil || !projectName.isEmpty || selectedRole != .any
    }

    // MARK: - Body

    var body: some View {
        List {
            dateRangeSection
            authorSection
            projectSection

            if hasActiveFilters {
                resetSection
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.bgPrimary)
        .navigationTitle("Filter Results")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(theme.textSecondary)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply") { applyFilters() }
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.accent)
            }
        }
        .onAppear { populateFromCurrentFilters() }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        #endif
    }

    // MARK: - Sections

    private var dateRangeSection: some View {
        Section {
            datePickerRow(label: "From", date: $dateFrom)
            datePickerRow(label: "To",   date: $dateTo)
        } header: {
            sectionHeader("Date Range")
        }
    }

    private var authorSection: some View {
        Section {
            rolePicker
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        } header: {
            sectionHeader("Author")
        }
    }

    private var projectSection: some View {
        Section {
            projectField
        } header: {
            sectionHeader("Project")
        } footer: {
            Text("Filters results to messages from sessions in the specified project.")
                .font(.system(size: theme.fontCaption - 1, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
    }

    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                resetFilters()
            } label: {
                HStack {
                    Spacer()
                    Label("Reset All Filters", systemImage: "arrow.counterclockwise")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    Spacer()
                }
            }
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func datePickerRow(label: String, date: Binding<Date?>) -> some View {
        HStack(spacing: theme.spacingSM) {
            Text(label)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Spacer()

            if let selectedDate = date.wrappedValue {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { selectedDate },
                        set: { date.wrappedValue = $0 }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()
                .tint(theme.accent)

                Button {
                    date.wrappedValue = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: theme.fontCaption + 2, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear \(label.lowercased()) date")
            } else {
                Button {
                    date.wrappedValue = Date()
                } label: {
                    Text("Any")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Set \(label.lowercased()) date")
            }
        }
    }

    private var rolePicker: some View {
        HStack(spacing: 0) {
            ForEach(RoleFilter.allCases, id: \.self) { role in
                Button {
                    selectedRole = role
                } label: {
                    Text(role.rawValue)
                        .font(.system(
                            size: theme.fontCaption,
                            weight: selectedRole == role ? .semibold : .regular,
                            design: theme.fontDesign
                        ))
                        .foregroundStyle(selectedRole == role ? theme.textPrimary : theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, theme.spacingSM)
                        .background(
                            selectedRole == role
                                ? theme.accent.opacity(0.15)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedRole == role ? .isSelected : [])
            }
        }
        .padding(4)
        .background(theme.bgTertiary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .accessibilityLabel("Author role filter")
    }

    private var projectField: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "folder")
                .font(.system(size: theme.fontCaption + 1, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 20)

            TextField("Project name", text: $projectName)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif

            if !projectName.isEmpty {
                Button {
                    projectName = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: theme.fontCaption + 2, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear project name")
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
            .kerning(1)
    }

    // MARK: - Actions

    private func populateFromCurrentFilters() {
        dateFrom = currentFilters.dateFrom
        dateTo = currentFilters.dateTo
        projectName = currentFilters.projectName ?? ""
        selectedRole = RoleFilter(from: currentFilters.role)
    }

    private func applyFilters() {
        let filters = SearchFilters(
            dateFrom: dateFrom,
            dateTo: dateTo,
            projectName: projectName.isEmpty ? nil : projectName,
            role: selectedRole.apiValue
        )
        onApply(filters)
        dismiss()
    }

    private func resetFilters() {
        dateFrom = nil
        dateTo = nil
        projectName = ""
        selectedRole = .any
    }
}
