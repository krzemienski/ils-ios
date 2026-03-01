import SwiftUI
import ILSShared
import UniformTypeIdentifiers
import TipKit

/// Navigation root for browsing, creating, importing, and deleting custom themes.
///
/// Displays all user-created themes in a swipe-to-delete `List`, with each row rendered
/// by ``ThemeRowView``. Tapping a row opens ``ThemeEditorView`` as a sheet pre-populated
/// with that theme's tokens; the toolbar "+" button opens a blank editor for creating a
/// new theme; and the "Import" button launches a `fileImporter` that decodes a JSON file
/// into a ``CustomTheme`` and persists it via the API.
///
/// State is managed by ``ThemesViewModel``, which is configured with the shared
/// `APIClient` on first appearance. Loading, empty-state, and error states are all
/// handled via ``ProgressView``, ``EmptyStateView``, and ``ErrorStateView`` overlays
/// respectively.
///
/// ## Topics
/// ### State
/// - ``viewModel`` - View model owning theme list, loading, and error state
/// - ``showingNewTheme`` - Controls the new-theme editor sheet
/// - ``selectedTheme`` - The theme currently open in the editor sheet
/// - ``showingImporter`` - Controls the JSON file-importer sheet
///
/// ### Actions
/// - ``deleteTheme(at:)`` - Deletes themes at the given index-set offsets
/// - ``handleImport(result:)`` - Parses and persists a theme from an imported JSON file
struct ThemesListView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot
    /// View model managing the theme list, loading state, and API interactions.
    @State private var viewModel = ThemesViewModel()

    // CONC-30: nonisolated removes implicit @MainActor isolation from this static property
    // so it can be accessed from Task.detached. JSONDecoder is Sendable so nonisolated(unsafe)
    // is unnecessary and produces a compiler warning — plain nonisolated suffices.
    nonisolated private static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    @State private var showingNewTheme = false
    @State private var selectedTheme: CustomTheme?
    @State private var showingImporter = false
    @State private var importErrorMessage: String?
    @State private var showImportError = false

    private let themeTip = ThemeTip()

    var body: some View {
        List {
            TipView(themeTip)
                .tipBackground(theme.bgSecondary)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if let error = viewModel.error {
                ErrorStateView(error: error) {
                    await viewModel.retryLoadThemes()
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.themes) { theme in
                    ThemeRowView(theme: theme)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTheme = theme
                        }
                }
                .onDelete(perform: deleteTheme)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Custom Themes")
        .inlineNavigationBarTitle()
        .refreshable {
            #if os(iOS)
            HapticManager.impact(.light)
            #endif
            await viewModel.loadThemes()
        }
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingImporter = true }) {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
            }
            #else
            ToolbarItem {
                Button(action: { showingImporter = true }) {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
            }
            #endif

            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingNewTheme = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewTheme) {
            NavigationStack {
                ThemeEditorView()
            }
            .environment(viewModel)
        }
        .sheet(item: $selectedTheme) { theme in
            NavigationStack {
                ThemeEditorView(theme: theme)
            }
            .environment(viewModel)
        }
        .overlay {
            if viewModel.isLoading && viewModel.themes.isEmpty {
                ProgressView("Loading themes...")
            } else if viewModel.themes.isEmpty && !viewModel.isLoading && viewModel.error == nil {
                EmptyStateView(
                    title: "No Custom Themes",
                    systemImage: "paintpalette",
                    description: "Create a custom theme to personalize your app",
                    actionTitle: "Create Theme"
                ) {
                    showingNewTheme = true
                }
            }
        }
        .task {
            viewModel.configure(client: appState.apiClient)
            await viewModel.loadThemes()
        }
        .onChange(of: appState.serverURL) { _, _ in
            viewModel.configure(client: appState.apiClient)
            Task { await viewModel.loadThemes() }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            Task {
                await handleImport(result: result)
            }
        }
        .background(theme.bgPrimary)
        .alert("Import Error", isPresented: $showImportError) {
            Button("OK", role: .cancel) { }
        } message: {
            if let message = importErrorMessage {
                Text(message)
            }
        }
    }

    private func deleteTheme(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let theme = viewModel.themes[index]
                await viewModel.deleteTheme(theme)
            }
        }
    }

    private func handleImport(result: Result<[URL], Error>) async {
        do {
            guard let fileURL = try result.get().first else {
                importErrorMessage = "No file selected"
                showImportError = true
                return
            }

            // Read file data
            guard fileURL.startAccessingSecurityScopedResource() else {
                importErrorMessage = "Unable to access file"
                showImportError = true
                return
            }
            // CRIT-SP1: Security-scoped resources are thread-bound on iOS.
            // Read raw bytes on the calling thread (where the scope is active),
            // then decode off-thread to avoid blocking UI with JSON parsing.
            let jsonData: Data
            do {
                jsonData = try Data(contentsOf: fileURL)
            } catch {
                fileURL.stopAccessingSecurityScopedResource()
                throw error
            }
            fileURL.stopAccessingSecurityScopedResource()

            // Decode off main thread — Data is Sendable, safe to cross boundary.
            let importedTheme = try await Task.detached(priority: .userInitiated) {
                try Self.jsonDecoder.decode(CustomTheme.self, from: jsonData)
            }.value

            // Create theme via API
            let created = await viewModel.createTheme(
                name: importedTheme.name,
                description: importedTheme.description,
                author: importedTheme.author,
                version: importedTheme.version,
                colors: importedTheme.colors,
                typography: importedTheme.typography,
                spacing: importedTheme.spacing,
                cornerRadius: importedTheme.cornerRadius,
                shadows: importedTheme.shadows
            )

            if created == nil {
                importErrorMessage = "Failed to create theme from imported file"
                showImportError = true
            }
        } catch {
            importErrorMessage = "Failed to import theme: \(error.localizedDescription)"
            showImportError = true
        }
    }
}

/// A single row in the themes list that summarises a ``CustomTheme``'s metadata.
///
/// Displays the theme name (bold), optional version badge, description (up to 2 lines),
/// author attribution, a set of capability icons indicating which token categories the
/// theme defines (colors, typography, spacing), and a relative timestamp for the last
/// update.
///
/// Used exclusively as a list cell inside ``ThemesListView``; interaction (tap-to-edit,
/// swipe-to-delete) is handled by the parent view.
struct ThemeRowView: View {
    let theme: CustomTheme
    @Environment(\.theme) private var appTheme: ThemeSnapshot

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(theme.name)
                    .font(.system(size: appTheme.fontBody, weight: .semibold, design: appTheme.fontDesign))
                    .foregroundStyle(appTheme.textPrimary)

                Spacer()

                if let version = theme.version {
                    Text("v\(version)")
                        .font(.system(size: appTheme.fontCaption, design: appTheme.fontDesign))
                        .foregroundStyle(appTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(appTheme.bgTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: appTheme.cornerRadiusSmall))
                }
            }

            if let description = theme.description {
                Text(description)
                    .font(.system(size: appTheme.fontCaption, design: appTheme.fontDesign))
                    .foregroundStyle(appTheme.textSecondary)
                    .lineLimit(2)
            }

            if let author = theme.author {
                Text("by \(author)")
                    .font(.system(size: appTheme.fontCaption, design: appTheme.fontDesign))
                    .foregroundStyle(appTheme.textTertiary)
                    .lineLimit(1)
            }

            HStack {
                if theme.colors != nil {
                    Label("Colors", systemImage: "paintpalette.fill")
                        .font(.system(size: appTheme.fontCaption, design: appTheme.fontDesign))
                        .foregroundStyle(appTheme.textTertiary)
                }

                if theme.typography != nil {
                    Label("Typography", systemImage: "textformat")
                        .font(.system(size: appTheme.fontCaption, design: appTheme.fontDesign))
                        .foregroundStyle(appTheme.textTertiary)
                }

                if theme.spacing != nil {
                    Label("Spacing", systemImage: "ruler")
                        .font(.system(size: appTheme.fontCaption, design: appTheme.fontDesign))
                        .foregroundStyle(appTheme.textTertiary)
                }

                Spacer()

                Text(formattedDate(theme.updatedAt))
                    .font(.system(size: appTheme.fontCaption, design: appTheme.fontDesign))
                    .foregroundStyle(appTheme.textTertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formattedDate(_ date: Date) -> String {
        Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    NavigationStack {
        ThemesListView()
    }
}
