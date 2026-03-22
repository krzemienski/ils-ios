import SwiftUI
import ILSShared

/// Full-text search across all session messages.
///
/// Presents a persistent search bar with debounced-as-you-type execution,
/// a scrollable filter chips row (role, code-only), and a results list using
/// ``GlobalSearchResultRow``. When the query is empty the view shows recent
/// search history as tappable chips.
///
/// ## Topics
/// ### Inputs
/// - ``apiClient`` - The API client used to configure the view model
/// - ``onNavigate`` - Called with the destination session ID when a result is tapped
struct GlobalSearchView: View {
    let apiClient: APIClient
    let onNavigate: (UUID) -> Void

    @State private var viewModel = GlobalSearchViewModel()
    @State private var showDateSheet = false
    @FocusState private var isSearchFocused: Bool

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar
                .padding(.horizontal, theme.spacingMD)
                .padding(.top, theme.spacingSM)
                .padding(.bottom, theme.spacingXS)

            // Filter chips row
            filterChipsRow
                .padding(.bottom, theme.spacingXS)

            Divider()
                .overlay(theme.divider)

            // Body: history / results / empty
            ZStack {
                if viewModel.searchQuery.isEmpty {
                    historyState
                } else if viewModel.isLoading {
                    loadingState
                } else if viewModel.searchResults.isEmpty {
                    noResultsState
                } else {
                    resultsContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Search")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .sheet(isPresented: $showDateSheet) {
            dateFilterSheet
        }
        .onAppear {
            viewModel.configure(client: apiClient)
            Task { await viewModel.loadHistory() }
            isSearchFocused = true
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.textTertiary)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))

            TextField("Search all sessions…", text: $viewModel.searchQuery)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .focused($isSearchFocused)
                .onChange(of: viewModel.searchQuery) {
                    viewModel.scheduleSearch()
                }

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                    viewModel.searchResults = []
                    viewModel.totalResults = 0
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.textTertiary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, theme.spacingXS)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
    }

    // MARK: - Filter Chips

    private var filterChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacingXS) {
                // Role filter
                roleChip(role: nil, label: "Any")
                roleChip(role: .user, label: "User")
                roleChip(role: .assistant, label: "Claude")

                Divider()
                    .frame(height: 20)
                    .overlay(theme.border)

                // Date range button
                Button {
                    showDateSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: theme.fontCaption - 1))
                        Text(dateRangeLabel)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    }
                    .foregroundStyle(hasDateFilter ? theme.textOnAccent : theme.textSecondary)
                    .padding(.horizontal, theme.spacingSM)
                    .padding(.vertical, 6)
                    .background(hasDateFilter ? theme.accent : theme.bgSecondary)
                    .clipShape(Capsule())
                }
                .accessibilityLabel("Date range filter")

                // Code-only toggle
                Button {
                    viewModel.codeOnly.toggle()
                    viewModel.scheduleSearch()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: theme.fontCaption - 1))
                        Text("Code")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    }
                    .foregroundStyle(viewModel.codeOnly ? theme.textOnAccent : theme.textSecondary)
                    .padding(.horizontal, theme.spacingSM)
                    .padding(.vertical, 6)
                    .background(viewModel.codeOnly ? theme.accent : theme.bgSecondary)
                    .clipShape(Capsule())
                }
                .accessibilityLabel(viewModel.codeOnly ? "Code only filter active" : "Filter to code blocks only")

                // Clear filters button (shown when any filter is active)
                if viewModel.hasActiveFilters {
                    Button {
                        viewModel.clearFilters()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: theme.fontCaption - 1, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                            .padding(.horizontal, theme.spacingSM)
                            .padding(.vertical, 6)
                            .background(theme.bgSecondary)
                            .clipShape(Capsule())
                    }
                    .accessibilityLabel("Clear all filters")
                }
            }
            .padding(.horizontal, theme.spacingMD)
        }
    }

    @ViewBuilder
    private func roleChip(role: MessageRole?, label: String) -> some View {
        let isSelected = viewModel.selectedRole == role
        Button {
            viewModel.selectedRole = role
            viewModel.scheduleSearch()
        } label: {
            Text(label)
                .font(.system(size: theme.fontCaption, weight: isSelected ? .semibold : .regular, design: theme.fontDesign))
                .foregroundStyle(isSelected ? theme.textOnAccent : theme.textSecondary)
                .padding(.horizontal, theme.spacingSM)
                .padding(.vertical, 6)
                .background(isSelected ? theme.accent : theme.bgSecondary)
                .clipShape(Capsule())
        }
        .accessibilityLabel("\(label) role filter\(isSelected ? ", selected" : "")")
    }

    // MARK: - Results Content

    private var resultsContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Result count header
                HStack {
                    Text("\(viewModel.totalResults) result\(viewModel.totalResults == 1 ? "" : "s")")
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                    Spacer()
                }
                .padding(.horizontal, theme.spacingMD)
                .padding(.vertical, theme.spacingXS)

                ForEach(viewModel.searchResults) { result in
                    GlobalSearchResultRow(result: result) { tapped in
                        onNavigate(tapped.sessionId)
                    }
                    .padding(.horizontal, theme.spacingMD)

                    Divider()
                        .overlay(theme.divider)
                        .padding(.leading, theme.spacingMD + 20 + theme.spacingSM)
                }
            }
        }
        .background(theme.bgPrimary)
    }

    // MARK: - History State

    @ViewBuilder
    private var historyState: some View {
        if viewModel.searchHistory.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacingSM) {
                    HStack {
                        Text("Recent Searches")
                            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                        Spacer()
                        Button {
                            Task { await viewModel.clearHistory() }
                        } label: {
                            Text("Clear")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.accent)
                        }
                        .accessibilityLabel("Clear search history")
                    }
                    .padding(.horizontal, theme.spacingMD)
                    .padding(.top, theme.spacingMD)

                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.searchHistory) { entry in
                            Button {
                                viewModel.searchQuery = entry.query
                                Task { await viewModel.search() }
                            } label: {
                                HStack(spacing: theme.spacingSM) {
                                    Image(systemName: "clock")
                                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                        .foregroundStyle(theme.textTertiary)
                                        .frame(width: 20, alignment: .center)

                                    Text(entry.query)
                                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                        .foregroundStyle(theme.textPrimary)
                                        .lineLimit(1)

                                    Spacer()

                                    if entry.resultCount > 0 {
                                        Text("\(entry.resultCount)")
                                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                            .foregroundStyle(theme.textTertiary)
                                    }
                                }
                                .padding(.horizontal, theme.spacingMD)
                                .padding(.vertical, theme.spacingSM)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .overlay(theme.divider)
                                .padding(.leading, theme.spacingMD + 20 + theme.spacingSM)
                        }
                    }
                }
            }
            .background(theme.bgPrimary)
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: theme.spacingMD) {
            Spacer()
            ProgressView()
                .progressViewStyle(.circular)
                .tint(theme.textSecondary)
            Text("Searching…")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - No Results State

    private var noResultsState: some View {
        VStack(spacing: theme.spacingMD) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 44, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
            VStack(spacing: theme.spacingXS) {
                Text("No results")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Text("No messages match \"\(viewModel.searchQuery)\"")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, theme.spacingXL)
            }
            if viewModel.hasActiveFilters {
                Button {
                    viewModel.clearFilters()
                } label: {
                    Text("Clear Filters")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textOnAccent)
                        .padding(.horizontal, theme.spacingLG)
                        .padding(.vertical, theme.spacingSM)
                        .background(theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty State (no query, no history)

    private var emptyState: some View {
        VStack(spacing: theme.spacingMD) {
            Spacer()
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 44, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
            VStack(spacing: theme.spacingXS) {
                Text("Search Messages")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Text("Find any message across all your sessions")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, theme.spacingXL)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Date Filter Sheet

    private var dateFilterSheet: some View {
        NavigationStack {
            Form {
                Section("From") {
                    DatePicker(
                        "Start date",
                        selection: Binding(
                            get: { viewModel.dateFrom ?? Date() },
                            set: { viewModel.dateFrom = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .labelsHidden()

                    if viewModel.dateFrom != nil {
                        Button("Clear start date") {
                            viewModel.dateFrom = nil
                        }
                        .foregroundStyle(theme.accent)
                    }
                }

                Section("To") {
                    DatePicker(
                        "End date",
                        selection: Binding(
                            get: { viewModel.dateTo ?? Date() },
                            set: { viewModel.dateTo = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .labelsHidden()

                    if viewModel.dateTo != nil {
                        Button("Clear end date") {
                            viewModel.dateTo = nil
                        }
                        .foregroundStyle(theme.accent)
                    }
                }
            }
            .navigationTitle("Date Range")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showDateSheet = false
                        viewModel.scheduleSearch()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") {
                        viewModel.dateFrom = nil
                        viewModel.dateTo = nil
                        showDateSheet = false
                        viewModel.scheduleSearch()
                    }
                }
            }
        }
        .environment(\.theme, theme)
        #if os(iOS)
        .presentationDetents([.medium])
        #endif
    }

    // MARK: - Helpers

    private var hasDateFilter: Bool {
        viewModel.dateFrom != nil || viewModel.dateTo != nil
    }

    private var dateRangeLabel: String {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        if let from = viewModel.dateFrom, let to = viewModel.dateTo {
            return "\(df.string(from: from))–\(df.string(from: to))"
        } else if let from = viewModel.dateFrom {
            return "From \(df.string(from: from))"
        } else if let to = viewModel.dateTo {
            return "To \(df.string(from: to))"
        }
        return "Dates"
    }
}
