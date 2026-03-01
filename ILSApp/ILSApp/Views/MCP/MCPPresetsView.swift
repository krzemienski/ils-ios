import SwiftUI
import ILSShared

// MARK: - MCP Presets View

/// Browsable template library for popular MCP server configurations.
/// Displays presets grouped by category with search and filtering support.
/// Callers receive the selected preset via the `onSelect` closure.
struct MCPPresetsView: View {
    var viewModel: MCPViewModel
    /// Called with the chosen preset so the caller can apply it and dismiss.
    var onSelect: (MCPPreset) -> Void

    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var searchText = ""
    @State private var selectedCategory: MCPPresetCategory? = nil
    @FocusState private var isSearchFocused: Bool
    @State private var filteredPresets: [MCPPreset] = []
    @State private var availableCategories: [MCPPresetCategory] = []

    // MARK: - Filter Computation

    private func computeFilteredPresets() -> [MCPPreset] {
        var results = viewModel.presets

        if let category = selectedCategory {
            results = results.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            results = results.filter {
                $0.name.lowercased().contains(query) ||
                $0.description.lowercased().contains(query) ||
                $0.command.lowercased().contains(query)
            }
        }

        return results
    }

    private func computeAvailableCategories() -> [MCPPresetCategory] {
        let usedCategories = Set(viewModel.presets.map(\.category))
        return MCPPresetCategory.allCases.filter { usedCategories.contains($0) }
    }

    private func refreshFilters() {
        filteredPresets = computeFilteredPresets()
        availableCategories = computeAvailableCategories()
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                    .padding(.horizontal, theme.spacingMD)
                    .padding(.top, theme.spacingSM)
                    .padding(.bottom, theme.spacingXS)

                // Category filter chips
                if !availableCategories.isEmpty {
                    categoryFilter
                        .padding(.bottom, theme.spacingSM)
                }

                // Content
                ScrollView {
                    LazyVStack(spacing: theme.spacingSM) {
                        if viewModel.isLoading && viewModel.presets.isEmpty {
                            loadingContent
                        } else if filteredPresets.isEmpty {
                            emptyState
                        } else {
                            ForEach(filteredPresets) { preset in
                                presetRow(preset)
                            }
                        }
                    }
                    .padding(.horizontal, theme.spacingMD)
                    .padding(.bottom, theme.spacingLG)
                }
                .refreshable {
                    await viewModel.loadPresets()
                }
            }
            .background(theme.bgPrimary)
            .navigationTitle("MCP Presets")
            #if os(iOS)
            .inlineNavigationBarTitle()
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(theme.accent)
                }
            }
            .task {
                if viewModel.presets.isEmpty {
                    await viewModel.loadPresets()
                }
                refreshFilters()
            }
            .onChange(of: searchText) { _, _ in refreshFilters() }
            .onChange(of: selectedCategory) { _, _ in refreshFilters() }
            .onChange(of: viewModel.presets) { _, _ in refreshFilters() }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.textTertiary)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
            TextField("Search presets…", text: $searchText)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .focused($isSearchFocused)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.textTertiary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, theme.spacingMD)
        .padding(.vertical, theme.spacingSM)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .focusRing(isFocused: isSearchFocused, cornerRadius: theme.cornerRadiusSmall)
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacingSM) {
                // "All" chip
                categoryChip(
                    label: "All",
                    isSelected: selectedCategory == nil,
                    color: theme.entityMCP
                ) {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        selectedCategory = nil
                    }
                }

                ForEach(availableCategories, id: \.self) { category in
                    categoryChip(
                        label: categoryLabel(category),
                        isSelected: selectedCategory == category,
                        color: categoryColor(category)
                    ) {
                        HapticManager.selection()
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                            selectedCategory = selectedCategory == category ? nil : category
                        }
                    }
                }
            }
            .padding(.horizontal, theme.spacingMD)
        }
    }

    private func categoryChip(
        label: String,
        isSelected: Bool,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if isSelected {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                }
                Text(label)
                    .font(.system(size: theme.fontCaption, weight: isSelected ? .semibold : .regular, design: theme.fontDesign))
                    .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? color.opacity(0.15) : theme.bgSecondary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) category filter\(isSelected ? ", selected" : "")")
    }

    // MARK: - Preset Row

    private func presetRow(_ preset: MCPPreset) -> some View {
        Button {
            HapticManager.selection()
            onSelect(preset)
        } label: {
            HStack(spacing: theme.spacingMD) {
                // Category icon
                ZStack {
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                        .fill(categoryColor(preset.category).opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: categoryIcon(preset.category))
                        .font(.system(size: 18))
                        .foregroundStyle(categoryColor(preset.category))
                }

                // Details
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(preset.name)
                            .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        // Category badge
                        Text(categoryLabel(preset.category))
                            .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(categoryColor(preset.category))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(categoryColor(preset.category).opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    Text(preset.description)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    // Command preview
                    HStack(spacing: 4) {
                        Image(systemName: "terminal")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                        Text(presetCommandPreview(preset))
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                            .lineLimit(1)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(preset.name), \(preset.description)")
            .accessibilityHint("Tap to use this preset")
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 40, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
            Text(searchText.isEmpty && selectedCategory == nil ? "No Presets" : "No Results")
                .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
            Text(searchText.isEmpty && selectedCategory == nil
                 ? "No preset configurations are available"
                 : "Try a different search or category")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacingXL)
    }

    // MARK: - Loading

    private var loadingContent: some View {
        SkeletonListView()
    }

    // MARK: - Helpers

    private func presetCommandPreview(_ preset: MCPPreset) -> String {
        guard !preset.args.isEmpty else { return preset.command }
        let argsPreview = preset.args.prefix(2).joined(separator: " ")
        let suffix = preset.args.count > 2 ? " …" : ""
        return "\(preset.command) \(argsPreview)\(suffix)"
    }

    private func categoryLabel(_ category: MCPPresetCategory) -> String {
        switch category {
        case .filesystem:    return "Filesystem"
        case .database:      return "Database"
        case .developer:     return "Developer"
        case .communication: return "Comms"
        case .web:           return "Web"
        case .utility:       return "Utility"
        }
    }

    private func categoryIcon(_ category: MCPPresetCategory) -> String {
        switch category {
        case .filesystem:    return "folder"
        case .database:      return "cylinder"
        case .developer:     return "hammer"
        case .communication: return "message"
        case .web:           return "globe"
        case .utility:       return "wrench.and.screwdriver"
        }
    }

    private func categoryColor(_ category: MCPPresetCategory) -> Color {
        switch category {
        case .filesystem:    return theme.entityMCP
        case .database:      return theme.accent
        case .developer:     return theme.entitySkill
        case .communication: return theme.entityPlugin
        case .web:           return theme.info
        case .utility:       return theme.warning
        }
    }
}
