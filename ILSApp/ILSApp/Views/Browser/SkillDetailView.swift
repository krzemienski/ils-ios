import SwiftUI
import MarkdownUI
import ILSShared

// MARK: - Skill Detail View

/// Detail view for inspecting and editing a single skill.
///
/// Displays the full skill record across five sections: a **Header** showing the source badge,
/// active status, description, and GitHub author/stars; a **Tags** strip with horizontally
/// scrollable capsule chips; a **Metadata** panel listing version, path, and last-updated date;
/// a **Content** section that toggles between a `MarkdownUI` renderer and a live `TextEditor`
/// when editing; and a **Markdown Theme** configuration that maps the app's ``ThemeSnapshot``
/// onto `MarkdownUI.Theme` styles.
///
/// The toolbar exposes an edit/save toggle and a delete button for `.local` and `.github` skills.
/// Both buttons show an inline `ProgressView` spinner while their respective async operations are
/// in flight and disable themselves to prevent double-submission.  Deletion dismisses the view on
/// completion via ``deleteSkill()``.
///
/// Source badge colour is determined by ``sourceColor``:
/// - `.local` → `theme.info` (blue)
/// - `.plugin` → `theme.entityPlugin` (purple)
/// - `.builtin` → `theme.accent` (primary accent)
/// - `.github` → `theme.warning` (amber)
///
/// A transient "Copied to clipboard" toast slides in from the bottom after ``copyContent()`` is
/// called and auto-dismisses after two seconds.  The toast animation respects the system
/// `accessibilityReduceMotion` preference.  Clipboard writes are platform-aware:
/// `UIPasteboard` on iOS, `NSPasteboard` on macOS.
///
/// ## Topics
/// ### State
/// - ``viewModel`` - Skills view model that performs network CRUD operations
/// - ``isEditing`` - Whether the content section is in edit mode
/// - ``editedContent`` - Live buffer for the TextEditor while editing
/// - ``showDeleteAlert`` - Controls the destructive-delete confirmation alert
/// - ``showCopiedToast`` - Drives the clipboard toast overlay visibility
/// - ``isSaving`` - True while an async save operation is in flight
/// - ``isDeleting`` - True while an async delete operation is in flight
///
/// ### View Components
/// - ``headerSection`` - Source badge, active status, description, and GitHub author row
/// - ``tagsSection`` - Horizontally scrollable tag chip strip
/// - ``metadataSection`` - Version, path, and last-updated metadata rows
/// - ``contentSection`` - Markdown renderer or TextEditor depending on edit mode
/// - ``markdownTheme`` - MarkdownUI theme derived from the current ThemeSnapshot
///
/// ### Actions
/// - ``startEditing()`` - Enters edit mode and seeds the editor buffer
/// - ``saveEdit()`` - Persists edited content via the view model and exits edit mode
/// - ``deleteSkill()`` - Deletes the skill via the view model and dismisses the view
/// - ``copyContent()`` - Copies raw skill content to the platform clipboard and shows the toast
struct SkillDetailView: View {
    let skill: Skill

    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    /// View model that performs network-backed CRUD operations for skills.
    @State private var viewModel = SkillsViewModel()
    /// Whether the content section is currently in edit mode.
    @State private var isEditing = false
    /// Live text buffer bound to the `TextEditor` while the user is editing the skill content.
    @State private var editedContent = ""
    /// Controls visibility of the destructive-delete confirmation alert.
    @State private var showDeleteAlert = false
    /// Controls visibility of the "Copied to clipboard" toast overlay.
    @State private var showCopiedToast = false
    /// True while the async save operation is in flight; disables toolbar buttons and shows a spinner.
    @State private var isSaving = false
    /// True while the async delete operation is in flight; disables toolbar buttons and shows a spinner.
    @State private var isDeleting = false

    /// Favorites manager for star/unstar action.
    @State private var favoritesManager = SkillFavoritesManager.shared

    /// Cached MarkdownUI theme — only rebuilt when the app theme changes.
    @State private var cachedMarkdownTheme: MarkdownUI.Theme = .basic
    @State private var cachedMarkdownThemeId: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingMD) {
                // Header Section
                headerSection

                // Tags Section
                if !skill.tags.isEmpty {
                    tagsSection
                }

                // Metadata Section
                metadataSection

                // Content Section
                contentSection
            }
            .padding(theme.spacingMD)
        }
        .background(theme.bgPrimary)
        .navigationTitle(skill.name)
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: theme.spacingSM) {
                    // Favorite button (shown for all skills)
                    Button {
                        Task { await favoritesManager.toggleFavorite(skill: skill) }
                    } label: {
                        Image(systemName: favoritesManager.isFavorite(skillName: skill.name) ? "star.fill" : "star")
                            .foregroundStyle(favoritesManager.isFavorite(skillName: skill.name) ? theme.warning : theme.textSecondary)
                    }
                    .accessibilityLabel(favoritesManager.isFavorite(skillName: skill.name) ? "Remove from Favorites" : "Add to Favorites")

                    if skill.source == .local || skill.source == .github {
                        Button {
                            if isEditing {
                                saveEdit()
                            } else {
                                startEditing()
                            }
                        } label: {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(theme.accent)
                            } else {
                                Image(systemName: isEditing ? "checkmark" : "pencil")
                                    .foregroundStyle(theme.accent)
                            }
                        }
                        .disabled(isSaving || isDeleting)
                        .accessibilityLabel(isEditing ? "Save" : "Edit")

                        Button {
                            showDeleteAlert = true
                        } label: {
                            if isDeleting {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(theme.error)
                            } else {
                                Image(systemName: "trash")
                                    .foregroundStyle(theme.error)
                            }
                        }
                        .disabled(isSaving || isDeleting)
                        .accessibilityLabel("Delete")
                    }
                }
            }
        }
        .alert("Delete Skill", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteSkill()
            }
        } message: {
            Text("Are you sure you want to delete '\(skill.name)'? This action cannot be undone.")
        }
        .overlay(alignment: .bottom) {
            if showCopiedToast {
                Text("Copied to clipboard")
                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textOnAccent)
                    .padding(.horizontal, theme.spacingMD)
                    .padding(.vertical, theme.spacingSM)
                    .background(theme.accent)
                    .clipShape(Capsule())
                    .padding(.bottom, theme.spacingLG)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: showCopiedToast)
        .task {
            viewModel.configure(client: appState.apiClient)
            editedContent = skill.rawContent ?? skill.content ?? ""
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack(spacing: theme.spacingSM) {
                // Source badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(sourceColor)
                        .frame(width: 8, height: 8)
                    Text(skill.source.rawValue.capitalized)
                        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(sourceColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(sourceColor.opacity(0.15))
                .clipShape(Capsule())

                Spacer()

                // Active status
                HStack(spacing: 4) {
                    Circle()
                        .fill(skill.isActive ? theme.success : theme.textTertiary)
                        .frame(width: 6, height: 6)
                    Text(skill.isActive ? "Active" : "Inactive")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(skill.isActive ? theme.success : theme.textTertiary)
                }
            }

            // Description
            if let description = skill.description {
                Text(description)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Author link (for GitHub skills)
            if let author = skill.author, skill.source == .github {
                HStack(spacing: 6) {
                    Image(systemName: "person.circle")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.accent)
                    Text(author)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.accent)

                    if let stars = skill.stars {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.warning)
                            Text("\(stars)")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                }
            }
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
    }

    // MARK: - Tags Section

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("TAGS")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .tracking(1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: theme.spacingSM) {
                    ForEach(skill.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(theme.entitySkill.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Metadata Section

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("INFORMATION")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .tracking(1)

            VStack(spacing: theme.spacingSM) {
                if let version = skill.version {
                    metadataRow(label: "Version", value: version)
                }

                metadataRow(label: "Path", value: skill.path)

                if let lastUpdated = skill.lastUpdated {
                    metadataRow(label: "Last Updated", value: lastUpdated)
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: theme.spacingSM) {
            Text(label)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 100, alignment: .leading)

            Text(value)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack {
                Text("SKILL CONTENT")
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .tracking(1)

                Spacer()

                if !isEditing {
                    Button {
                        copyContent()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.accent)
                    }
                    .accessibilityLabel("Copy content")
                }
            }

            if isEditing {
                TextEditor(text: $editedContent)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .background(theme.bgSecondary)
                    .frame(minHeight: 300)
                    .padding(theme.spacingMD)
                    .modifier(GlassCard())
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Markdown(skill.rawContent ?? skill.content ?? "")
                        .markdownTheme(cachedMarkdownTheme)
                        .markdownCodeSyntaxHighlighter(ILSCodeHighlighter())
                        .textSelection(.enabled)
                        .padding(theme.spacingMD)
                        .onChange(of: theme.id, initial: true) {
                            guard theme.id != cachedMarkdownThemeId else { return }
                            cachedMarkdownThemeId = theme.id
                            cachedMarkdownTheme = buildSkillMarkdownTheme(from: theme)
                        }
                }
                .modifier(GlassCard())
            }
        }
    }

    // MARK: - Markdown Theme

    /// Build a MarkdownUI theme dynamically from current AppTheme tokens.
    /// Only called when theme.id changes via onChange.
    private func buildSkillMarkdownTheme(from t: ThemeSnapshot) -> MarkdownUI.Theme {
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

    private var sourceColor: Color {
        switch skill.source {
        case .local: return theme.info
        case .plugin: return theme.entityPlugin
        case .builtin: return theme.accent
        case .github: return theme.warning
        }
    }

    private func startEditing() {
        isEditing = true
        editedContent = skill.rawContent ?? skill.content ?? ""
    }

    private func saveEdit() {
        guard !editedContent.isEmpty else { return }

        isSaving = true
        Task {
            if await viewModel.updateSkill(skill, content: editedContent) != nil {
                await MainActor.run {
                    isEditing = false
                    isSaving = false
                }
            } else {
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }

    private func deleteSkill() {
        isDeleting = true
        Task {
            await viewModel.deleteSkill(skill)
            await MainActor.run {
                isDeleting = false
                dismiss()
            }
        }
    }

    private func copyContent() {
        #if os(iOS)
        UIPasteboard.general.string = skill.rawContent ?? skill.content ?? ""
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(skill.rawContent ?? skill.content ?? "", forType: .string)
        #endif
        // SA-MED-4: ToastModifier handles auto-dismiss — no manual timer needed.
        showCopiedToast = true
    }
}
