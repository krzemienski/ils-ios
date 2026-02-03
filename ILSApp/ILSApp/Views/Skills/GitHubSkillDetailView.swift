import SwiftUI
import ILSShared

struct GitHubSkillDetailView: View {
    let repository: GitHubRepository
    @ObservedObject var viewModel: SkillsViewModel

    @State private var skillDetail: GitHubSkillDetail?
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ILSTheme.spacingM) {
                if isLoading {
                    ProgressView("Loading skill details...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, ILSTheme.spacingXL)
                } else if let detail = skillDetail {
                    // Repository info
                    VStack(alignment: .leading, spacing: ILSTheme.spacingS) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(detail.repository.name)
                                    .font(ILSTheme.titleFont)
                                Text(detail.repository.owner.login)
                                    .font(ILSTheme.captionFont)
                                    .foregroundColor(ILSTheme.secondaryText)
                            }

                            Spacer()

                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text("\(detail.repository.stargazersCount)")
                                    .font(ILSTheme.bodyFont)
                                    .foregroundColor(ILSTheme.secondaryText)
                            }
                        }

                        if let description = detail.repository.description {
                            Text(description)
                                .font(ILSTheme.bodyFont)
                                .foregroundColor(ILSTheme.secondaryText)
                        }
                    }

                    Divider()

                    // Skill content (SKILL.md)
                    VStack(alignment: .leading, spacing: ILSTheme.spacingS) {
                        Text("Skill Documentation")
                            .font(ILSTheme.headlineFont)

                        Text(detail.skillContent)
                            .font(ILSTheme.bodyFont)
                            .textSelection(.enabled)
                    }
                } else {
                    ContentUnavailableView(
                        "Skill Not Available",
                        systemImage: "doc.text.image",
                        description: Text("Unable to load skill details")
                    )
                }
            }
            .padding(ILSTheme.spacingM)
        }
        .navigationTitle(repository.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Install") {
                    // Installation will be wired up in phase 4
                }
                .disabled(isLoading)
            }
        }
        .task {
            await loadSkillDetail()
        }
    }

    private func loadSkillDetail() async {
        isLoading = true
        skillDetail = await viewModel.loadGitHubSkillDetail(
            owner: repository.owner.login,
            repo: repository.name
        )
        isLoading = false
    }
}
