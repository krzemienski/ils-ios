import SwiftUI

/// Full article detail view showing title, category badge, body text, optional code
/// example, related articles, and a toolbar bookmark toggle.
///
/// - Note: Full implementation provided in subtask-3-2. This stub satisfies the
///   build dependency required by ``DocumentationView``.
struct DocumentationArticleView: View {
    let article: DocArticle

    @Environment(\.theme) private var theme: ThemeSnapshot

    private let docService = DocumentationService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingMD) {
                Text(article.title)
                    .font(.system(size: theme.fontTitle2, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Text(article.body)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(theme.spacingMD)
        }
        .background(theme.bgPrimary)
        .navigationTitle(article.title)
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .preferredColorScheme(.dark)
    }
}
