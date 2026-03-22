import SwiftUI

// MARK: - DocumentationArticleView

/// Full article detail view showing the article title, category badge, body text,
/// an optional code example with a one-tap copy button, a toolbar bookmark toggle,
/// and a Related Articles section at the bottom listing other articles in the same
/// category.
///
/// Follows the same GlassCard / sectionCard pattern used in ``MCPTroubleshootView``
/// and uses the theme environment for consistent typography and colours.
struct DocumentationArticleView: View {
    let article: DocArticle

    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showCopiedToast = false

    private let docService = DocumentationService.shared

    // MARK: - Computed

    /// Articles in the same category, excluding the current article.
    private var relatedArticles: [DocArticle] {
        docService.articles(for: article.category).filter { $0.id != article.id }
    }

    private var isBookmarked: Bool {
        docService.isBookmarked(article.id)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingMD) {
                categoryBadge

                sectionCard(title: "Overview") {
                    Text(article.body)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }

                if let code = article.codeExample {
                    sectionCard(title: "Example") {
                        codeExampleCard(code: code)
                    }
                }

                if !relatedArticles.isEmpty {
                    sectionCard(title: "Related Articles") {
                        relatedArticlesContent
                    }
                }
            }
            .padding(theme.spacingMD)
        }
        .background(theme.bgPrimary)
        .navigationTitle(article.title)
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            ToolbarItem(placement: toolbarPlacement) {
                Button {
                    HapticManager.selection()
                    docService.toggleBookmark(article.id)
                } label: {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(isBookmarked ? theme.accent : theme.textSecondary)
                }
                .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Add bookmark")
                .accessibilityHint(isBookmarked ? "Removes this article from bookmarks" : "Saves this article to bookmarks")
            }
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
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: isBookmarked)
        .preferredColorScheme(.dark)
    }

    // MARK: - Category Badge

    private var categoryBadge: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: article.category.icon)
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.accent)
            Text(article.category.rawValue)
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.accent)
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, theme.spacingXS)
        .background(theme.accent.opacity(0.15))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Category: \(article.category.rawValue)")
    }

    // MARK: - Code Example Card

    @ViewBuilder
    private func codeExampleCard(code: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row with copy button
            HStack {
                Text("EXAMPLE")
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .tracking(1)
                Spacer()
                Button {
                    copyToClipboard(code)
                } label: {
                    HStack(spacing: theme.spacingXS) {
                        Image(systemName: showCopiedToast ? "checkmark" : "doc.on.doc")
                            .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        Text(showCopiedToast ? "Copied" : "Copy")
                            .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                    }
                    .foregroundStyle(showCopiedToast ? theme.success : theme.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Copy code example")
                .accessibilityHint("Copies the example to your clipboard")
            }
            .padding(.bottom, theme.spacingSM)

            Divider().background(theme.divider)

            // Code content
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: theme.fontCaption, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, theme.spacingSM)
            }
        }
    }

    // MARK: - Related Articles

    @ViewBuilder
    private var relatedArticlesContent: some View {
        VStack(spacing: 0) {
            ForEach(Array(relatedArticles.enumerated()), id: \.element.id) { index, related in
                NavigationLink(destination: DocumentationArticleView(article: related)) {
                    HStack(spacing: theme.spacingMD) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(related.title)
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(related.summary)
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .padding(.vertical, theme.spacingXS)
                }
                .buttonStyle(.plain)

                if index < relatedArticles.count - 1 {
                    Divider().background(theme.divider).padding(.vertical, theme.spacingXS)
                }
            }
        }
    }

    // MARK: - Section Card Helper

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text(title.uppercased())
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .tracking(1)

            content()
                .padding(theme.spacingMD)
                .modifier(GlassCard())
        }
    }

    // MARK: - Clipboard

    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        showCopiedToast = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                showCopiedToast = false
            }
        }
    }

    // MARK: - Platform

    private var toolbarPlacement: ToolbarItemPlacement {
        #if os(iOS)
        return .navigationBarTrailing
        #else
        return .automatic
        #endif
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DocumentationArticleView(
            article: DocArticle.allArticles.first(where: { $0.codeExample != nil })
                ?? DocArticle.allArticles[0]
        )
    }
}
