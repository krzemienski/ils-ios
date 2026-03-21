import SwiftUI
import ILSShared

/// Horizontal filter bar displayed above the kanban board.
///
/// Provides search, project filtering, date range selection, and a clear-all button.
/// All filter state is bound to the parent ``SessionKanbanViewModel`` via `@Bindable`.
///
/// ## Topics
/// ### Filters
/// - ``searchBar`` - Text field matching the pattern in ``UnifiedSessionsView``
/// - ``projectPills`` - Horizontally-scrollable row of tappable project pills
/// - ``dateRangePicker`` - Picker for ``FilterDateRange`` presets
/// - ``clearFiltersButton`` - Shown when any filter is active
struct KanbanFilterBarView: View {

    // MARK: - Inputs

    @Bindable var viewModel: SessionKanbanViewModel

    // MARK: - Environment

    @Environment(\.theme) private var theme: ThemeSnapshot
    @FocusState private var isSearchFocused: Bool

    // MARK: - Date Range Options

    /// Preset date range options displayed in the picker.
    private static let dateRangeOptions: [(label: String, value: FilterDateRange?)] = [
        ("Any Time", nil),
        ("Today", .today),
        ("Yesterday", .yesterday),
        ("This Week", .thisWeek),
        ("Last Week", .lastWeek),
        ("This Month", .thisMonth),
        ("Last Month", .lastMonth),
    ]

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            searchBar

            // Only show project pills if there are projects to filter by
            if !viewModel.availableProjects.isEmpty {
                projectPills
            }

            HStack(spacing: theme.spacingSM) {
                dateRangePicker

                Spacer()

                if viewModel.hasActiveFilters {
                    clearFiltersButton
                }
            }
            .padding(.horizontal, theme.spacingMD)
        }
        .padding(.bottom, theme.spacingSM)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
            TextField("Search sessions...", text: $viewModel.searchText)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .accessibilityLabel("Search kanban board")
                .focused($isSearchFocused)
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, theme.spacingXS + 2)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .focusRing(isFocused: isSearchFocused, cornerRadius: theme.cornerRadiusSmall)
        .padding(.horizontal, theme.spacingMD)
    }

    // MARK: - Project Pills

    private var projectPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacingXS) {
                // "All" pill to clear project filter
                projectPill(label: "All", isSelected: viewModel.selectedProject == nil) {
                    viewModel.selectedProject = nil
                }

                ForEach(viewModel.availableProjects, id: \.self) { project in
                    projectPill(label: project, isSelected: viewModel.selectedProject == project) {
                        if viewModel.selectedProject == project {
                            viewModel.selectedProject = nil
                        } else {
                            viewModel.selectedProject = project
                        }
                    }
                }
            }
            .padding(.horizontal, theme.spacingMD)
        }
    }

    /// A single tappable project filter pill.
    private func projectPill(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: theme.fontCaption, weight: isSelected ? .semibold : .regular, design: theme.fontDesign))
                .foregroundStyle(isSelected ? theme.bgPrimary : theme.textSecondary)
                .padding(.horizontal, theme.spacingSM)
                .padding(.vertical, theme.spacingXS)
                .background(isSelected ? theme.accent : theme.bgSecondary)
                .clipShape(Capsule())
        }
        .accessibilityLabel("\(label) project filter")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Date Range Picker

    private var dateRangePicker: some View {
        Menu {
            ForEach(Self.dateRangeOptions, id: \.label) { option in
                Button {
                    viewModel.dateRange = option.value
                } label: {
                    HStack {
                        Text(option.label)
                        if viewModel.dateRange == option.value {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: "calendar")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                Text(dateRangeLabel)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                Image(systemName: "chevron.down")
                    .font(.system(size: theme.fontCaption - 2, design: theme.fontDesign))
            }
            .foregroundStyle(viewModel.dateRange != nil ? theme.accent : theme.textSecondary)
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, theme.spacingXS)
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .accessibilityLabel("Date range filter")
    }

    /// Human-readable label for the currently selected date range.
    private var dateRangeLabel: String {
        if let range = viewModel.dateRange {
            return range.displayName.capitalized
        }
        return "Any Time"
    }

    // MARK: - Clear Filters

    private var clearFiltersButton: some View {
        Button {
            viewModel.clearFilters()
        } label: {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                Text("Clear Filters")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
            }
            .foregroundStyle(theme.accent)
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, theme.spacingXS)
            .background(theme.accent.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .accessibilityLabel("Clear all filters")
    }
}
