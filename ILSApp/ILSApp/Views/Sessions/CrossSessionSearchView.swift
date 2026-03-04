import SwiftUI
import ILSShared

/// Cross-session full-text search screen.
///
/// Provides a search bar with live-search-on-submit, a horizontal strip of
/// dismissible active-filter chips, a segmented Results/Bookmarks tab picker,
/// and a grouped `List` of ``SearchResultRowView`` rows with infinite scroll.
/// Tapping a row invokes ``onSessionTap`` with a minimal ``ChatSession`` built
/// from the ``MessageSearchResult`` so that the caller can navigate to the chat.
///
/// The toolbar exposes a "slider.horizontal.3" button that presents
/// ``SearchFiltersView`` as a sheet.  Applied filters are reflected immediately
/// as chips under the search bar; each chip carries an × button that removes
/// that individual filter and re-runs the search.
///
/// ## Topics
/// ### Inputs
/// - ``onSessionTap`` - Called when the user taps a result row; receives a minimal ``ChatSession``
///
/// ### View Sections
/// - ``searchBar`` - Text field + clear button
/// - ``filterChips`` - Scrollable horizontal row of active-filter dismissal chips
/// - ``resultsContent`` - Grouped list of search results with infinite scroll
/// - ``bookmarksContent`` - Flat list of bookmarked results
struct CrossSessionSearchView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// Called when the user taps a result row.  Receives a minimal ``ChatSession``
    /// built from the ``MessageSearchResult`` so the caller can navigate to the session.
    var onSessionTap: ((ChatSession) -> Void)?

    @State private var viewModel = CrossSessionSearchViewModel()
    @State private var showFilters = false
    @State private var selectedTab: SearchTab = .results

    // MARK: - Tab Enum

    private enum SearchTab: String, CaseIterable {
        case results   = "Results"
        case bookmarks = "Bookmarks"
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchBar

                if hasActiveFilters {
                    filterChips
                        .padding(.horizontal, theme.spacingMD)
                        .padding(.bottom, theme.spacingSM)
                }

                Picker("Tab", selection: $selectedTab) {
                    ForEach(SearchTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, theme.spacingMD)
                .padding(.vertical, theme.spacingSM)

                Divider().overlay(theme.divider)

                Group {
                    switch selectedTab {
                    case .results:
                        resultsContent
                    case .bookmarks:
                        bookmarksContent
                    }
                }
            }
            .background(theme.bgPrimary)
            .navigationTitle("Search Sessions")
            #if os(iOS)
            .inlineNavigationBarTitle()
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Filter search results")
                    .accessibilityHint("Opens the filter sheet to narrow results by date, author, or project")
                }
            }
            .sheet(isPresented: $showFilters) {
                NavigationView {
                    SearchFiltersView(currentFilters: viewModel.filters) { newFilters in
                        Task { await viewModel.applyFilters(newFilters) }
                    }
                }
                .environment(\.theme, theme)
            }
        }
        .task {
            viewModel.configure(client: appState.apiClient)
            await viewModel.loadBookmarks()
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.textTertiary)
                .accessibilityHidden(true)

            TextField("Search across sessions…", text: $viewModel.searchQuery)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .onSubmit {
                    Task { await viewModel.search() }
                }
                .accessibilityLabel("Search query")

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, theme.spacingMD)
        .padding(.vertical, theme.spacingSM)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .padding(.horizontal, theme.spacingMD)
        .padding(.vertical, theme.spacingSM)
    }

    // MARK: - Filter Chips

    private var hasActiveFilters: Bool {
        viewModel.filters.dateFrom != nil
            || viewModel.filters.dateTo != nil
            || (viewModel.filters.projectName?.isEmpty == false)
            || viewModel.filters.role != nil
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacingXS) {
                if let dateFrom = viewModel.filters.dateFrom {
                    filterChip(
                        label: "From: \(dateFrom.formatted(date: .abbreviated, time: .omitted))"
                    ) {
                        Task {
                            await viewModel.applyFilters(SearchFilters(
                                dateTo: viewModel.filters.dateTo,
                                projectName: viewModel.filters.projectName,
                                role: viewModel.filters.role
                            ))
                        }
                    }
                }

                if let dateTo = viewModel.filters.dateTo {
                    filterChip(
                        label: "To: \(dateTo.formatted(date: .abbreviated, time: .omitted))"
                    ) {
                        Task {
                            await viewModel.applyFilters(SearchFilters(
                                dateFrom: viewModel.filters.dateFrom,
                                projectName: viewModel.filters.projectName,
                                role: viewModel.filters.role
                            ))
                        }
                    }
                }

                if let project = viewModel.filters.projectName, !project.isEmpty {
                    filterChip(label: "Project: \(project)") {
                        Task {
                            await viewModel.applyFilters(SearchFilters(
                                dateFrom: viewModel.filters.dateFrom,
                                dateTo: viewModel.filters.dateTo,
                                role: viewModel.filters.role
                            ))
                        }
                    }
                }

                if let role = viewModel.filters.role {
                    filterChip(label: "Role: \(role.capitalized)") {
                        Task {
                            await viewModel.applyFilters(SearchFilters(
                                dateFrom: viewModel.filters.dateFrom,
                                dateTo: viewModel.filters.dateTo,
                                projectName: viewModel.filters.projectName
                            ))
                        }
                    }
                }
            }
        }
        .accessibilityLabel("Active search filters")
    }

    private func filterChip(label: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: theme.fontCaption - 2, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove filter: \(label)")
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, 4)
        .background(theme.accent.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Results Content

    @ViewBuilder
    private var resultsContent: some View {
        if viewModel.isLoading && viewModel.results.isEmpty {
            loadingView("Searching…")
        } else if let error = viewModel.error, viewModel.results.isEmpty {
            errorView(error.localizedDescription)
        } else if viewModel.isEmptySearch {
            searchPromptView
        } else if viewModel.results.isEmpty {
            emptyResultsView
        } else {
            List {
                ForEach(viewModel.groupedResults, id: \.key) { group in
                    Section {
                        ForEach(group.value) { result in
                            SearchResultRowView(
                                result: result,
                                isBookmarked: viewModel.isBookmarked(result),
                                onTap: { handleResultTap(result) },
                                onBookmark: {
                                    Task { await viewModel.toggleBookmark(result) }
                                }
                            )
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(theme.bgPrimary)
                            .onAppear {
                                if isLastResult(result, in: group.value),
                                   isLastGroup(group.key) {
                                    Task { await viewModel.loadMore() }
                                }
                            }
                        }
                    } header: {
                        Text(group.key)
                            .font(.system(
                                size: theme.fontCaption,
                                weight: .semibold,
                                design: theme.fontDesign
                            ))
                            .foregroundStyle(theme.textTertiary)
                            .textCase(.none)
                    }
                }

                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.vertical, theme.spacingMD)
                        Spacer()
                    }
                    .listRowBackground(theme.bgPrimary)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Bookmarks Content

    @ViewBuilder
    private var bookmarksContent: some View {
        if viewModel.isLoadingBookmarks {
            loadingView("Loading bookmarks…")
        } else if viewModel.bookmarks.isEmpty {
            emptyBookmarksView
        } else {
            List {
                ForEach(viewModel.bookmarks) { bookmark in
                    SearchResultRowView(
                        result: bookmark.result,
                        isBookmarked: true,
                        onTap: { handleResultTap(bookmark.result) },
                        onBookmark: {
                            Task { await viewModel.toggleBookmark(bookmark.result) }
                        }
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(theme.bgPrimary)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: - State Views

    private func loadingView(_ message: String) -> some View {
        VStack {
            Spacer()
            ProgressView(message)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
            Spacer()
        }
    }

    private var searchPromptView: some View {
        VStack(spacing: theme.spacingMD) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(theme.textTertiary)
            Text("Search Across Sessions")
                .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
            Text("Type a query and tap Return to find messages across all your sessions.")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacingXL)
            Spacer()
        }
    }

    private var emptyResultsView: some View {
        VStack(spacing: theme.spacingMD) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(theme.textTertiary)
            Text("No Results Found")
                .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
            Text("No messages matched \"\(viewModel.searchQuery)\". Try different keywords or adjust your filters.")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacingXL)
            Spacer()
        }
    }

    private var emptyBookmarksView: some View {
        VStack(spacing: theme.spacingMD) {
            Spacer()
            Image(systemName: "bookmark")
                .font(.system(size: 40))
                .foregroundStyle(theme.textTertiary)
            Text("No Bookmarks Yet")
                .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
            Text("Bookmark search results to save them for future reference.")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacingXL)
            Spacer()
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: theme.spacingMD) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(theme.warning)
            Text("Search Failed")
                .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
            Text(message)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacingXL)
            Button("Try Again") {
                Task { await viewModel.search() }
            }
            .foregroundStyle(theme.accent)
            Spacer()
        }
    }

    // MARK: - Helpers

    /// Build a minimal ``ChatSession`` from a search result for navigation purposes.
    private func chatSession(from result: MessageSearchResult) -> ChatSession {
        ChatSession(
            id: result.sessionId,
            name: result.sessionName,
            model: result.sessionModel ?? "sonnet",
            createdAt: result.createdAt,
            lastActiveAt: result.createdAt
        )
    }

    private func handleResultTap(_ result: MessageSearchResult) {
        onSessionTap?(chatSession(from: result))
    }

    private func isLastResult(
        _ result: MessageSearchResult,
        in group: [MessageSearchResult]
    ) -> Bool {
        group.last?.id == result.id
    }

    private func isLastGroup(_ key: String) -> Bool {
        viewModel.groupedResults.last?.key == key
    }
}
