import SwiftUI
import MarkdownUI
import ILSShared

/// Entity type for distinguishing skill vs plugin in the preview view.
enum GitHubEntityType {
    case skill
    case plugin
}

/// Preview view for a GitHub repository showing README content, file listing,
/// and install button with retry capability.
///
/// Pushed via NavigationLink from BrowserView's Discover tab when a user taps
/// a search result. Loads preview data (README + file tree) on appear via
/// the backend's /skills/preview or /plugins/preview endpoint.
struct GitHubPreviewView: View {
    let result: GitHubSearchResult
    let entityType: GitHubEntityType

    var skillsVM: SkillsViewModel
    var pluginsVM: PluginsViewModel

    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var preview: GitHubRepoPreview?
    @State private var isLoadingPreview = true
    @State private var installState: InstallState = .idle

    /// Cached MarkdownUI theme -- only rebuilt when the app theme changes.
    @State private var cachedMarkdownTheme: MarkdownUI.Theme = .basic
    @State private var cachedMarkdownThemeId: String = ""

    enum InstallState {
        case idle
        case installing
        case installed
        case failed(String)
    }

    init(result: GitHubSearchResult, entityType: GitHubEntityType,
         skillsVM: SkillsViewModel, pluginsVM: PluginsViewModel) {
        self.result = result
        self.entityType = entityType
        self.skillsVM = skillsVM
        self.pluginsVM = pluginsVM
    }

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingMD) {
                // Header
                headerSection

                // Install action
                installSection

                // README content
                readmeSection

                // File listing
                if let preview, !preview.files.isEmpty {
                    fileListSection(files: preview.files)
                }
            }
            .padding(theme.spacingMD)
        }
        .background(theme.bgPrimary)
        .navigationTitle(result.name.isEmpty ? result.repository : result.name)
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .task {
            await loadPreview()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            // Entity type badge + stars
            HStack(spacing: theme.spacingSM) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(entityColor)
                        .frame(width: 8, height: 8)
                    Text(entityType == .skill ? "Skill" : "Plugin")
                        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(entityColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(entityColor.opacity(0.15))
                .clipShape(Capsule())

                Spacer()

                if result.stars > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.warning)
                        Text("\(result.stars)")
                            .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }

            // Repository name
            Text(result.repository)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            // Description
            if let description = result.description {
                Text(description)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
    }

    // MARK: - Install Section

    private var installSection: some View {
        VStack(spacing: theme.spacingSM) {
            switch installState {
            case .idle:
                if isInstalled {
                    // Already installed
                    HStack(spacing: theme.spacingSM) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(theme.success)
                        Text("Installed")
                            .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.success)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(theme.spacingMD)
                    .modifier(GlassCard())
                } else {
                    Button {
                        Task { await installAction() }
                    } label: {
                        HStack(spacing: theme.spacingSM) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Install \(entityType == .skill ? "Skill" : "Plugin")")
                                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        }
                        .foregroundStyle(theme.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(theme.spacingMD)
                        .background(theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                    }
                    .buttonStyle(.plain)
                }

            case .installing:
                HStack(spacing: theme.spacingSM) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(theme.accent)
                    Text("Installing...")
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(theme.spacingMD)
                .modifier(GlassCard())

            case .installed:
                HStack(spacing: theme.spacingSM) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.success)
                    Text("Successfully Installed")
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.success)
                }
                .frame(maxWidth: .infinity)
                .padding(theme.spacingMD)
                .modifier(GlassCard())

            case .failed(let errorMessage):
                VStack(spacing: theme.spacingSM) {
                    HStack(spacing: theme.spacingSM) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(theme.error)
                        Text("Install Failed")
                            .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.error)
                    }

                    Text(errorMessage)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)

                    Button {
                        Task { await installAction() }
                    } label: {
                        HStack(spacing: theme.spacingSM) {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry")
                                .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        }
                        .foregroundStyle(theme.textOnAccent)
                        .padding(.horizontal, theme.spacingLG)
                        .padding(.vertical, theme.spacingSM)
                        .background(theme.accent)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(theme.spacingMD)
                .background(theme.error.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            }
        }
    }

    // MARK: - README Section

    @ViewBuilder
    private var readmeSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("README")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .tracking(1)

            if isLoadingPreview {
                // Loading skeleton
                VStack(spacing: theme.spacingSM) {
                    ForEach(0..<5, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(theme.bgTertiary)
                            .frame(height: 16)
                            .frame(maxWidth: .infinity)
                    }
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.bgTertiary)
                        .frame(height: 16)
                        .frame(width: 200, alignment: .leading)
                }
                .padding(theme.spacingMD)
                .modifier(GlassCard())
            } else if let readme = preview?.readme, !readme.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Markdown(readme)
                        .markdownTheme(cachedMarkdownTheme)
                        .markdownCodeSyntaxHighlighter(ILSCodeHighlighter())
                        .textSelection(.enabled)
                        .padding(theme.spacingMD)
                        .onChange(of: theme.id, initial: true) {
                            guard theme.id != cachedMarkdownThemeId else { return }
                            cachedMarkdownThemeId = theme.id
                            cachedMarkdownTheme = buildPreviewMarkdownTheme(from: theme)
                        }
                }
                .modifier(GlassCard())
            } else {
                HStack(spacing: theme.spacingSM) {
                    Image(systemName: "doc.text")
                        .foregroundStyle(theme.textTertiary)
                    Text("No README available")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(theme.spacingMD)
                .modifier(GlassCard())
            }
        }
    }

    // MARK: - File List Section

    private func fileListSection(files: [GitHubFileEntry]) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("FILES")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .tracking(1)

            VStack(spacing: 0) {
                // Sort: directories first, then files, alphabetically within each group
                let sorted = files.sorted { a, b in
                    if a.type != b.type {
                        return a.type == "dir"
                    }
                    return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                }

                ForEach(sorted) { file in
                    HStack(spacing: theme.spacingSM) {
                        Image(systemName: file.type == "dir" ? "folder.fill" : "doc.fill")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(file.type == "dir" ? theme.warning : theme.textTertiary)
                            .frame(width: 20)

                        Text(file.name)
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        if let size = file.size, file.type == "file" {
                            Text(formatFileSize(size))
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                    .padding(.horizontal, theme.spacingMD)
                    .padding(.vertical, theme.spacingSM)

                    if file.id != sorted.last?.id {
                        Divider()
                            .foregroundStyle(theme.divider)
                            .padding(.leading, theme.spacingMD + 20 + theme.spacingSM)
                    }
                }
            }
            .modifier(GlassCard())
        }
    }

    // MARK: - Markdown Theme

    /// Build a MarkdownUI theme from the current ThemeSnapshot.
    /// Mirrors the pattern from SkillDetailView.buildSkillMarkdownTheme.
    private func buildPreviewMarkdownTheme(from t: ThemeSnapshot) -> MarkdownUI.Theme {
        Theme()
            .text {
                ForegroundColor(t.textPrimary)
                FontSize(.em(0.95))
            }
            .heading1 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.bold)
                        FontSize(.em(1.4))
                        ForegroundColor(t.textPrimary)
                    }
                    .markdownMargin(top: 8, bottom: 4)
            }
            .heading2 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.bold)
                        FontSize(.em(1.2))
                        ForegroundColor(t.textPrimary)
                    }
                    .markdownMargin(top: 8, bottom: 4)
            }
            .heading3 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(1.1))
                        ForegroundColor(t.textPrimary)
                    }
                    .markdownMargin(top: 4, bottom: 4)
            }
            .blockquote { configuration in
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(t.accent.opacity(0.6))
                        .frame(width: 3)
                    configuration.label
                        .markdownTextStyle {
                            ForegroundColor(t.textSecondary)
                        }
                        .padding(.leading, 12)
                }
                .markdownMargin(top: 4, bottom: 4)
            }
            .codeBlock { configuration in
                ThemedCodeBlockView(
                    language: configuration.language,
                    code: configuration.content
                )
                .markdownMargin(top: 4, bottom: 4)
            }
            .code {
                FontFamilyVariant(.monospaced)
                ForegroundColor(t.accent)
                BackgroundColor(t.bgTertiary.opacity(0.5))
            }
            .paragraph { configuration in
                configuration.label
                    .markdownMargin(top: 2, bottom: 2)
            }
            .listItem { configuration in
                configuration.label
                    .markdownMargin(top: 1, bottom: 1)
            }
            .link {
                ForegroundColor(t.info)
            }
    }

    // MARK: - Helpers

    private var entityColor: Color {
        entityType == .skill ? theme.entitySkill : theme.entityPlugin
    }

    private var isInstalled: Bool {
        switch entityType {
        case .skill: return skillsVM.isInstalled(result: result)
        case .plugin: return pluginsVM.isInstalled(result: result)
        }
    }

    private func loadPreview() async {
        isLoadingPreview = true

        // Check if already installed
        if isInstalled {
            installState = .installed
        }

        switch entityType {
        case .skill:
            preview = await skillsVM.fetchPreview(repository: result.repository)
        case .plugin:
            preview = await pluginsVM.fetchPreview(repository: result.repository)
        }

        isLoadingPreview = false
    }

    private func installAction() async {
        installState = .installing
        let success: Bool
        switch entityType {
        case .skill:
            success = await skillsVM.installFromGitHub(result: result)
        case .plugin:
            success = await pluginsVM.installFromGitHub(result: result)
        }

        if success {
            installState = .installed
            HapticManager.impact(.medium)
        } else {
            let errorMsg: String
            switch entityType {
            case .skill:
                errorMsg = skillsVM.lastInstallError?.localizedDescription ?? "Unknown error"
            case .plugin:
                errorMsg = pluginsVM.lastInstallError?.localizedDescription ?? "Unknown error"
            }
            installState = .failed(errorMsg)
        }
    }

    private func formatFileSize(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
        }
    }
}
