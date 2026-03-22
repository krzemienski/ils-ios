import SwiftUI
import ILSShared

/// Main bookmarks browser showing all saved message bookmarks across all sessions.
///
/// Provides a search bar (filters by content, note, and session name), a horizontal
/// strip of tag filter chips, and a grouped ``List`` of ``MessageBookmarkRowView``
/// rows. The list can be grouped by session name or by date recency (Today /
/// Yesterday / This Week / Earlier). Swipe-to-delete removes individual bookmarks.
/// An empty state is shown when no bookmarks exist or no results match the query.
///
/// All bookmarks are read from and written to ``MessageBookmarksManager.shared``.
///
/// ## Topics
/// ### Inputs
/// - ``onBookmarkTap`` - Called when the user taps a row; receives the tapped ``MessageBookmark``
///
/// ### View Sections
/// - ``searchBar`` - Text field + clear button filtering by content / note / session
/// - ``tagFilterStrip`` - Horizontal scrollable row of tag chips; "All" deselects the filter
/// - ``bookmarksList`` - Grouped list with swipe-to-delete
/// - ``emptyState`` - Shown when no bookmarks exist or no results match the query
struct MessageBookmarksView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// Called when the user taps a bookmark row to navigate to the source message.
    var onBookmarkTap: ((MessageBookmark) -> Void)?

    @State private var manager = MessageBookmarksManager.shared
    @State private var searchText = ""
    @State private var selectedTag: String? = nil
    @State private var groupBySession = true
    @State private var showExportSheet = false

    // MARK: - Computed

    /// All distinct tag names across all bookmarks, sorted alphabetically.
    private var allTagNames: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for bookmark in manager.bookmarks {
            for tag in bookmark.tags {
                if seen.insert(tag).inserted {
                    result.append(tag)
                }
            }
        }
        return result.sorted()
    }

    /// Bookmarks after applying search text and selected tag filter.
    private var filteredBookmarks: [MessageBookmark] {
        manager.bookmarks.filter { bookmark in
            let matchesSearch: Bool
            if searchText.isEmpty {
                matchesSearch = true
            } else {
                let query = searchText.lowercased()
                matchesSearch =
                    (bookmark.messageContent?.lowercased().contains(query) == true)
                    || (bookmark.note?.lowercased().contains(query) == true)
                    || (bookmark.sessionName?.lowercased().contains(query) == true)
                    || bookmark.tags.contains { $0.lowercased().contains(query) }
            }

            let matchesTag: Bool
            if let tag = selectedTag {
                matchesTag = bookmark.tags.contains(tag)
            } else {
                matchesTag = true
            }

            return matchesSearch && matchesTag
        }
    }

    /// Bookmarks grouped by session name, each group sorted newest-first.
    private var groupedBySession: [(key: String, bookmarks: [MessageBookmark])] {
        var grouped: [String: [MessageBookmark]] = [:]
        for bookmark in filteredBookmarks {
            let key = bookmark.sessionName ?? "Session \(bookmark.sessionId.uuidString.prefix(8))"
            grouped[key, default: []].append(bookmark)
        }
        return grouped
            .map { ($0.key, $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted {
                ($0.bookmarks.first?.createdAt ?? .distantPast)
                    > ($1.bookmarks.first?.createdAt ?? .distantPast)
            }
    }

    /// Bookmarks grouped by recency label (Today / Yesterday / This Week / Earlier).
    private var groupedByDate: [(key: String, bookmarks: [MessageBookmark])] {
        var grouped: [String: [MessageBookmark]] = [:]
        let now = Date()
        let calendar = Calendar.current
        for bookmark in filteredBookmarks {
            let label: String
            if calendar.isDateInToday(bookmark.createdAt) {
                label = "Today"
            } else if calendar.isDateInYesterday(bookmark.createdAt) {
                label = "Yesterday"
            } else if let days = calendar.dateComponents([.day], from: bookmark.createdAt, to: now).day,
                      days < 7
            {
                label = "This Week"
            } else {
                label = "Earlier"
            }
            grouped[label, default: []].append(bookmark)
        }
        let order = ["Today", "Yesterday", "This Week", "Earlier"]
        return order.compactMap { key -> (key: String, bookmarks: [MessageBookmark])? in
            guard let bookmarks = grouped[key], !bookmarks.isEmpty else { return nil }
            return (key, bookmarks.sorted { $0.createdAt > $1.createdAt })
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchBar

                if !allTagNames.isEmpty {
                    tagFilterStrip
                        .padding(.bottom, theme.spacingSM)
                }

                Divider().overlay(theme.divider)

                if filteredBookmarks.isEmpty {
                    emptyState
                } else {
                    bookmarksList
                }
            }
            .background(theme.bgPrimary)
            .navigationTitle("Bookmarks")
            #if os(iOS)
            .inlineNavigationBarTitle()
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        groupBySession.toggle()
                    } label: {
                        Image(systemName: groupBySession ? "calendar" : "folder")
                    }
                    .accessibilityLabel(groupBySession ? "Group by date" : "Group by session")
                    .accessibilityHint(groupBySession ? "Switch to grouping bookmarks by date" : "Switch to grouping bookmarks by session")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showExportSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(manager.bookmarks.isEmpty)
                    .accessibilityLabel("Export Bookmarks")
                    .accessibilityHint("Export all bookmarks as Markdown or JSON")
                }
            }
            .sheet(isPresented: $showExportSheet) {
                BookmarkExportSheet(bookmarks: manager.bookmarks)
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.textTertiary)
                .accessibilityHidden(true)

            TextField("Search bookmarks…", text: $searchText)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .accessibilityLabel("Search bookmarks")

            if !searchText.isEmpty {
                Button {
                    searchText = ""
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

    // MARK: - Tag Filter Strip

    private var tagFilterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacingXS) {
                tagChip(label: "All", isSelected: selectedTag == nil) {
                    selectedTag = nil
                }

                ForEach(allTagNames, id: \.self) { tagName in
                    tagChip(label: tagName, isSelected: selectedTag == tagName) {
                        selectedTag = selectedTag == tagName ? nil : tagName
                    }
                }
            }
            .padding(.horizontal, theme.spacingMD)
        }
    }

    @ViewBuilder
    private func tagChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(isSelected ? .white : theme.textSecondary)
                .padding(.horizontal, theme.spacingSM)
                .padding(.vertical, theme.spacingXS)
                .background(isSelected ? theme.accent : theme.bgSecondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Bookmarks List

    private var bookmarksList: some View {
        List {
            let groups = groupBySession ? groupedBySession : groupedByDate
            ForEach(groups, id: \.key) { key, bookmarks in
                Section {
                    ForEach(bookmarks) { bookmark in
                        MessageBookmarkRowView(bookmark: bookmark) {
                            onBookmarkTap?(bookmark)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(
                            top: 0,
                            leading: theme.spacingSM,
                            bottom: 0,
                            trailing: theme.spacingSM
                        ))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task {
                                    await manager.removeBookmark(messageId: bookmark.messageId)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    groupHeader(label: key)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(theme.bgPrimary)
    }

    @ViewBuilder
    private func groupHeader(label: String) -> some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: groupBySession ? "folder" : "calendar")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
            Text(label.uppercased())
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
            Spacer()
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, theme.spacingXS)
        .background(theme.bgPrimary)
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: theme.spacingMD) {
            Spacer()

            Image(systemName: "bookmark.slash")
                .font(.system(size: 48))
                .foregroundStyle(theme.textTertiary)

            if manager.bookmarks.isEmpty {
                Text("No Bookmarks Yet")
                    .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Text("Long-press any message in a session to bookmark it for quick reference.")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, theme.spacingXL)
            } else {
                Text("No Results")
                    .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Text("No bookmarks match your search or filter.")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, theme.spacingXL)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bgPrimary)
    }
}

// MARK: - BookmarkExportSheet

/// Format-picker sheet for exporting bookmarks.
///
/// Presents a segmented `Picker` with Markdown and JSON options and an Export
/// button that builds the export content and presents the system share sheet.
private struct BookmarkExportSheet: View {
    let bookmarks: [MessageBookmark]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot

    @State private var selectedFormat: BookmarkExportFormat = .markdown
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section("Format") {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(BookmarkExportFormat.allCases) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    formatDescriptionRow
                }

                Section {
                    HStack {
                        Image(systemName: "bookmark.fill")
                            .foregroundStyle(theme.accent)
                        Text("\(bookmarks.count) bookmark\(bookmarks.count == 1 ? "" : "s") will be exported")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.bgPrimary)
            .navigationTitle("Export Bookmarks")
            #if os(iOS)
            .inlineNavigationBarTitle()
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        triggerExport()
                    } label: {
                        Text("Export")
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: shareItems)
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var formatDescriptionRow: some View {
        HStack(spacing: 12) {
            Image(systemName: selectedFormat.iconName)
                .font(.system(size: 20))
                .foregroundStyle(theme.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(selectedFormat.displayName)
                    .font(.body)
                    .foregroundStyle(theme.textPrimary)

                Text(selectedFormat.exportDescription)
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Export Logic

    private func triggerExport() {
        switch selectedFormat {
        case .markdown:
            let content = exportMarkdown(bookmarks: bookmarks)
            let sheet = ShareSheet(text: content, fileName: "bookmarks.md")
            shareItems = sheet.activityItems
            showShareSheet = true
        case .json:
            if let data = exportJSON(bookmarks: bookmarks) {
                let fileURL = writeToShareExports(data: data, fileName: "bookmarks.json")
                if let url = fileURL {
                    shareItems = [url]
                    showShareSheet = true
                }
            }
        }
    }

    /// Builds a Markdown document from all bookmarks, grouped by session.
    private func exportMarkdown(bookmarks: [MessageBookmark]) -> String {
        var md = "# Bookmarks\n\n"
        md += "_Exported \(Date().formatted(date: .long, time: .shortened))_\n\n---\n\n"

        for (index, bookmark) in bookmarks.enumerated() {
            let sessionName = bookmark.sessionName ?? "Session \(bookmark.sessionId.uuidString.prefix(8))"
            md += "## Bookmark \(index + 1)\n\n"
            md += "**Session:** \(sessionName)\n\n"

            if let content = bookmark.messageContent, !content.isEmpty {
                md += "**Message:**\n\n> \(content.replacingOccurrences(of: "\n", with: "\n> "))\n\n"
            }

            if !bookmark.tags.isEmpty {
                md += "**Tags:** \(bookmark.tags.joined(separator: ", "))\n\n"
            }

            if let note = bookmark.note, !note.isEmpty {
                md += "**Note:** \(note)\n\n"
            }

            md += "---\n\n"
        }

        return md
    }

    /// Builds a JSON array from all bookmarks using `JSONEncoder`.
    private func exportJSON(bookmarks: [MessageBookmark]) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(bookmarks)
    }

    /// Writes `data` to `Caches/ShareExports/<fileName>` and returns the URL.
    private func writeToShareExports(data: Data, fileName: String) -> URL? {
        guard let cachesBase = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let exportDir = cachesBase.appendingPathComponent("ShareExports", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
            let fileURL = exportDir.appendingPathComponent(fileName)
            try data.write(to: fileURL)
            return fileURL
        } catch {
            AppLogger.shared.error(
                "BookmarkExportSheet file write failed: \(error.localizedDescription)",
                category: "export"
            )
            return nil
        }
    }
}

// MARK: - BookmarkExportFormat

private enum BookmarkExportFormat: String, CaseIterable, Identifiable {
    case markdown
    case json

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .markdown: return "Markdown"
        case .json:     return "JSON"
        }
    }

    var iconName: String {
        switch self {
        case .markdown: return "text.alignleft"
        case .json:     return "curlybraces"
        }
    }

    var exportDescription: String {
        switch self {
        case .markdown: return "Human-readable document with each bookmark as a formatted section."
        case .json:     return "Structured data with all bookmark fields, suitable for import or processing."
        }
    }
}
