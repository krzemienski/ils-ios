import SwiftUI

/// Searchable list of all Claude Code documentation articles grouped by category.
///
/// Shows a **Bookmarks** section at the top when the user has at least one bookmarked
/// article, followed by one section per ``DocCategory``. All sections are filtered by a
/// single ``searchText`` binding via `.searchable`, with a 200 ms debounce applied via
/// `.task(id:)` matching the pattern in `CommandPaletteView`.
///
/// Tapping an article navigates to ``DocumentationArticleView`` via `NavigationLink`.
/// An optional ``contextHint`` pre-populates the search field on first appearance —
/// useful for context-sensitive entry points (e.g. `"mcp"` or `"permissions"`).
///
/// ## Topics
/// ### State
/// - ``searchText`` - Live search query that filters all category sections
/// - ``searchResults`` - Debounced filtered article set
///
/// ### Initialisation
/// - ``init(contextHint:)`` - Optionally pre-populate the search field
struct DocumentationView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// Optional context hint to pre-populate the search field on first appearance.
    let contextHint: String?

    /// Live search text used to filter articles across all sections.
    @State private var searchText = ""
    /// Debounced filtered articles matching the current search query.
    @State private var searchResults: [DocArticle] = DocArticle.allArticles

    private let docService = DocumentationService.shared

    init(contextHint: String? = nil) {
        self.contextHint = contextHint
    }

    var body: some View {
        List {
            let bookmarked = visibleBookmarks
            if !bookmarked.isEmpty {
                Section("Bookmarks") {
                    ForEach(bookmarked) { article in
                        NavigationLink(destination: DocumentationArticleView(article: article)) {
                            ArticleRow(article: article, isBookmarked: true, theme: theme)
                        }
                    }
                }
            }

            ForEach(DocCategory.allCases) { category in
                let articles = searchResults.filter { $0.category == category }
                if !articles.isEmpty {
                    Section {
                        ForEach(articles) { article in
                            NavigationLink(destination: DocumentationArticleView(article: article)) {
                                ArticleRow(
                                    article: article,
                                    isBookmarked: docService.isBookmarked(article.id),
                                    theme: theme
                                )
                            }
                        }
                    } header: {
                        Label(category.rawValue, systemImage: category.icon)
                            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                            .foregroundStyle(theme.accent)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.bgPrimary)
        .searchable(text: $searchText, prompt: "Search documentation...")
        .navigationTitle("Documentation")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        #if os(iOS)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(theme.bgPrimary, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        #endif
        .task {
            if let hint = contextHint, !hint.isEmpty, searchText.isEmpty {
                searchText = hint.replacingOccurrences(of: "_", with: " ")
            }
        }
        .task(id: searchText) {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            searchResults = docService.search(searchText)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Computed Properties

    /// Bookmarked articles visible under the current search filter.
    ///
    /// When search is empty, returns all bookmarks. When filtering, returns only
    /// bookmarked articles that also appear in ``searchResults``.
    private var visibleBookmarks: [DocArticle] {
        if searchText.isEmpty {
            return docService.bookmarkedArticles
        }
        return searchResults.filter { docService.isBookmarked($0.id) }
    }
}

// MARK: - Article Row

/// Styled list row displaying an article's title, summary, and optional bookmark indicator.
private struct ArticleRow: View {
    let article: DocArticle
    let isBookmarked: Bool
    let theme: ThemeSnapshot

    var body: some View {
        HStack(spacing: theme.spacingMD) {
            VStack(alignment: .leading, spacing: 2) {
                Text(article.title)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Text(article.summary)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            if isBookmarked {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: theme.fontCaption))
                    .foregroundStyle(theme.accent)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        DocumentationView()
    }
}
