import SwiftUI
import ILSShared

struct GitHubSkillDetailView: View {
    let repository: GitHubRepository
    @ObservedObject var viewModel: SkillsViewModel

    @State private var skillDetail: GitHubSkillDetail?
    @State private var isLoading = true
    @State private var isInstalling = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
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
                if isInstalling {
                    ProgressView()
                } else {
                    Button("Install") {
                        installSkill()
                    }
                    .disabled(isLoading)
                }
            }
        }
        .alert("Installation Successful", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("The skill has been installed successfully and is now available in your skills list.")
        }
        .alert("Installation Failed", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
            Button("Retry") {
                installSkill()
            }
        } message: {
            Text(errorMessage)
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

    private func installSkill() {
        isInstalling = true

        Task {
            let success = await viewModel.installGitHubSkill(
                owner: repository.owner.login,
                repo: repository.name,
                htmlUrl: repository.htmlUrl
            )

            await MainActor.run {
                isInstalling = false

                if success {
                    showSuccessAlert = true
                } else {
                    errorMessage = viewModel.error?.localizedDescription ?? "Failed to install skill. Please try again."
                    showErrorAlert = true
                }
            }
        }
    }
}
