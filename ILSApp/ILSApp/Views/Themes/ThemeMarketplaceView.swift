import SwiftUI
import UniformTypeIdentifiers

// MARK: - Theme Category

enum ThemeCategory: String, CaseIterable {
    case all = "All"
    case dark = "Dark"
    case light = "Light"
    case cyberpunk = "Cyberpunk"
    case nature = "Nature"
    case minimal = "Minimal"

    /// Maps built-in theme IDs to categories for filtering.
    static func category(for themeID: String) -> ThemeCategory {
        switch themeID {
        case "cyberpunk", "neon-noir", "electric-grid":
            return .cyberpunk
        case "paper", "snow":
            return .light
        case "obsidian", "midnight", "carbon", "graphite", "slate":
            return .dark
        case "ember", "crimson":
            return .nature
        case "ghost-protocol":
            return .minimal
        default:
            return .dark
        }
    }
}

// MARK: - Theme Marketplace View

/// Marketplace for browsing, previewing, and importing themes.
///
/// Displays built-in themes as a grid of preview cards with search and category
/// filtering. Supports importing themes from JSON files and exporting the
/// currently active theme.
struct ThemeMarketplaceView: View {
    @Environment(\.theme) private var theme
    @Environment(ThemeManager.self) var themeManager

    @State private var searchText = ""
    @State private var selectedCategory: ThemeCategory = .all
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var importError: String?
    @State private var showImportError = false
    @State private var exportData: Data?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, theme.spacingMD)
                .padding(.vertical, theme.spacingSM)

            categoryFilter
                .padding(.bottom, theme.spacingSM)

            themeGrid
        }
        .background(theme.bgPrimary)
        .navigationTitle("Theme Marketplace")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                toolbarMenu
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: exportData.map { ThemeJSONDocument(data: $0) },
            contentType: .json,
            defaultFilename: exportFilename
        ) { result in
            if case .failure(let err) = result {
                importError = "Export failed: \(err.localizedDescription)"
                showImportError = true
            }
        }
        .alert("Error", isPresented: $showImportError) {
            Button("OK", role: .cancel) { }
        } message: {
            if let errorMsg = importError {
                Text(errorMsg)
            }
        }
    }

    // MARK: - Export Filename

    private var exportFilename: String {
        "\(themeManager.currentTheme.id)-theme.json"
    }

    // MARK: - Theme Grid

    private var themeGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: theme.spacingSM) {
                ForEach(filteredThemes, id: \.id) { builtinTheme in
                    themeCard(for: builtinTheme)
                }
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.bottom, theme.spacingLG)
        }
    }

    private func themeCard(for builtinTheme: any AppTheme) -> some View {
        let isActive = builtinTheme.id == themeManager.currentTheme.id
        return ThemePreviewCard(
            themeName: builtinTheme.name,
            author: "ILS Team",
            bgColor: builtinTheme.bgPrimary,
            accentColor: builtinTheme.accent,
            textColor: builtinTheme.textPrimary,
            secondaryTextColor: builtinTheme.textSecondary,
            isActive: isActive,
            onTap: {
                themeManager.setTheme(builtinTheme.id)
            }
        )
    }

    // MARK: - Toolbar Menu

    private var toolbarMenu: some View {
        Menu {
            Button {
                showingImporter = true
            } label: {
                Label("Import Theme", systemImage: "square.and.arrow.down")
            }

            Button {
                exportCurrentTheme()
            } label: {
                Label("Export Current Theme", systemImage: "square.and.arrow.up")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(theme.textSecondary)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.textTertiary)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
            TextField("Search themes...", text: $searchText)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
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
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacingSM) {
                ForEach(ThemeCategory.allCases, id: \.self) { category in
                    categoryButton(category)
                }
            }
            .padding(.horizontal, theme.spacingMD)
        }
    }

    private func categoryButton(_ category: ThemeCategory) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            selectedCategory = category
        } label: {
            Text(category.rawValue)
                .font(.system(
                    size: theme.fontCaption,
                    weight: isSelected ? .semibold : .regular,
                    design: theme.fontDesign
                ))
                .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? theme.accent.opacity(0.2) : theme.bgSecondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(category.rawValue) category filter")
    }

    // MARK: - Filtered Themes

    private var filteredThemes: [any AppTheme] {
        let themes = themeManager.availableThemes

        let categoryFiltered: [any AppTheme]
        if selectedCategory == .all {
            categoryFiltered = themes
        } else {
            categoryFiltered = themes.filter { t in
                ThemeCategory.category(for: t.id) == selectedCategory
            }
        }

        if searchText.isEmpty {
            return categoryFiltered
        }
        return categoryFiltered.filter { t in
            t.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Import / Export

    private func handleImport(result: Result<[URL], Error>) {
        do {
            guard let fileURL = try result.get().first else {
                importError = "No file selected"
                showImportError = true
                return
            }

            guard fileURL.startAccessingSecurityScopedResource() else {
                importError = "Unable to access file"
                showImportError = true
                return
            }
            defer { fileURL.stopAccessingSecurityScopedResource() }

            let jsonData = try Data(contentsOf: fileURL)
            let manifest = try JSONDecoder().decode(ThemeManifest.self, from: jsonData)

            let imported = ImportedTheme(manifest: manifest)
            themeManager.registerTheme(imported)
            themeManager.setTheme(imported.id)

        } catch {
            importError = "Failed to import theme: \(error.localizedDescription)"
            showImportError = true
        }
    }

    private func exportCurrentTheme() {
        let current = themeManager.currentTheme
        let manifest = ThemeManifest(
            name: current.name,
            author: "ILS User",
            version: "1.0.0",
            description: "Exported from ILS app",
            colors: ThemeManifest.ThemeColors(
                background: current.bgPrimary.hexString,
                backgroundSecondary: current.bgSecondary.hexString,
                accent: current.accent.hexString,
                text: current.textPrimary.hexString,
                textSecondary: current.textSecondary.hexString,
                border: current.border.hexString
            )
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            exportData = try encoder.encode(manifest)
            showingExporter = true
        } catch {
            importError = "Failed to export theme: \(error.localizedDescription)"
            showImportError = true
        }
    }
}

// MARK: - Imported Theme

/// Runtime theme constructed from a ThemeManifest JSON import.
private struct ImportedTheme: AppTheme {
    let name: String
    let id: String

    let bgPrimary: Color
    let bgSecondary: Color
    let bgTertiary: Color
    let bgSidebar: Color

    let accent: Color
    let accentSecondary: Color
    var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, accentSecondary], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let textOnAccent: Color

    let success: Color
    let warning: Color
    let error: Color
    let info: Color

    let border: Color
    let borderSubtle: Color
    let divider: Color

    let glassBackground: Color
    let glassBorder: Color

    let cornerRadius: CGFloat = 12
    let cornerRadiusSmall: CGFloat = 8
    let cornerRadiusLarge: CGFloat = 20

    let spacingXS: CGFloat = 4
    let spacingSM: CGFloat = 8
    let spacingMD: CGFloat = 16
    let spacingLG: CGFloat = 24
    let spacingXL: CGFloat = 32

    let fontCaption: CGFloat = 11
    let fontBody: CGFloat = 15
    let fontTitle3: CGFloat = 18
    let fontTitle2: CGFloat = 22
    let fontTitle1: CGFloat = 28

    init(manifest: ThemeManifest) {
        self.name = manifest.name
        self.id = manifest.name.lowercased().replacingOccurrences(of: " ", with: "-")

        let bg = Color(hex: manifest.colors.background)
        self.bgPrimary = bg
        self.bgSecondary = Color(hex: manifest.colors.backgroundSecondary)
        self.bgTertiary = Color(hex: manifest.colors.backgroundSecondary)
        self.bgSidebar = Color(hex: manifest.colors.backgroundSecondary)

        let accentClr = Color(hex: manifest.colors.accent)
        self.accent = accentClr
        self.accentSecondary = accentClr.opacity(0.7)

        self.textPrimary = Color(hex: manifest.colors.text)
        self.textSecondary = Color(hex: manifest.colors.textSecondary)
        self.textTertiary = Color(hex: manifest.colors.textSecondary).opacity(0.7)
        self.textOnAccent = Color.white

        self.success = Color(hex: "00ff88")
        self.warning = Color(hex: "ffd000")
        self.error = Color(hex: "ff3366")
        self.info = Color(hex: "a855f7")

        self.border = Color(hex: manifest.colors.border)
        self.borderSubtle = Color(hex: manifest.colors.border).opacity(0.5)
        self.divider = Color(hex: manifest.colors.border)

        self.glassBackground = bg.opacity(0.8)
        self.glassBorder = Color(hex: manifest.colors.border)
    }
}

// MARK: - Theme JSON Document

/// FileDocument wrapper for theme JSON export.
struct ThemeJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let fileData = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = fileData
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Color Hex Export

extension Color {
    /// Approximates a hex string from the Color value.
    /// Uses UIColor on iOS for component extraction.
    var hexString: String {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(
            format: "%02X%02X%02X",
            Int(r * 255),
            Int(g * 255),
            Int(b * 255)
        )
        #else
        let nsColor = NSColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(
            format: "%02X%02X%02X",
            Int(r * 255),
            Int(g * 255),
            Int(b * 255)
        )
        #endif
    }
}
