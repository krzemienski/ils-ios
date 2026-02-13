import SwiftUI
import ILSShared
import UniformTypeIdentifiers

struct ThemesListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ThemesViewModel()
    @State private var showingNewTheme = false
    @State private var selectedTheme: CustomTheme?
    @State private var showingImporter = false
    @State private var importErrorMessage: String?
    @State private var showImportError = false

    var body: some View {
        List {
            if let error = viewModel.error {
                ErrorStateView(error: error) {
                    await viewModel.retryLoadThemes()
                }
            } else if viewModel.themes.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    title: "No Custom Themes",
                    systemImage: "paintpalette",
                    description: "Create a custom theme to personalize your app",
                    actionTitle: "Create Theme"
                ) {
                    showingNewTheme = true
                }
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
        .navigationTitle("Custom Themes")
        .refreshable {
            await viewModel.loadThemes()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingImporter = true }) {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingNewTheme = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewTheme) {
            Text("New Theme Editor - Coming Soon")
        }
        .sheet(item: $selectedTheme) { theme in
            Text("Theme Editor for \(theme.name) - Coming Soon")
        }
        .overlay {
            if viewModel.isLoading && viewModel.themes.isEmpty {
                ProgressView("Loading themes...")
            }
        }
        .task {
            viewModel.configure(client: appState.apiClient)
            await viewModel.loadThemes()
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
            defer { fileURL.stopAccessingSecurityScopedResource() }

            let jsonData = try Data(contentsOf: fileURL)

            // Decode theme
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let importedTheme = try decoder.decode(CustomTheme.self, from: jsonData)

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

struct ThemeRowView: View {
    let theme: CustomTheme

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(theme.name)
                    .font(ILSTheme.headlineFont)

                Spacer()

                if let version = theme.version {
                    Text("v\(version)")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(ILSTheme.tertiaryBackground)
                        .cornerRadius(ILSTheme.cornerRadiusS)
                }
            }

            if let description = theme.description {
                Text(description)
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.secondaryText)
                    .lineLimit(2)
            }

            if let author = theme.author {
                Text("by \(author)")
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.tertiaryText)
                    .lineLimit(1)
            }

            HStack {
                // Show which token categories are customized
                if theme.colors != nil {
                    Label("Colors", systemImage: "paintpalette.fill")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.tertiaryText)
                }

                if theme.typography != nil {
                    Label("Typography", systemImage: "textformat")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.tertiaryText)
                }

                if theme.spacing != nil {
                    Label("Spacing", systemImage: "ruler")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.tertiaryText)
                }

                Spacer()

                Text(formattedDate(theme.updatedAt))
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.tertiaryText)
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
