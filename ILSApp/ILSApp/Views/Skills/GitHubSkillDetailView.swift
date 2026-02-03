import SwiftUI
import ILSShared

struct GitHubSkillDetailView: View {
    let repository: GitHubRepository
    @ObservedObject var viewModel: SkillsViewModel

    @State private var skillDetail: GitHubSkillDetail?
    @State private var isLoading = true
    @State private var loadError: Error?
    @State private var isInstalling = false
    @State private var showSuccessAlert = false
    @State private var showInstallErrorAlert = false
    @State private var installErrorMessage = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ILSTheme.spacingM) {
                if isLoading {
                    ProgressView("Loading skill details...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, ILSTheme.spacingXL)
                } else if let error = loadError {
                    // Show error state with retry for loading failures
                    VStack(spacing: ILSTheme.spacingM) {
                        ErrorStateView(error: error) {
                            await loadSkillDetail()
                        }
                    }
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
        .alert("Installation Failed", isPresented: $showInstallErrorAlert) {
            Button("OK", role: .cancel) {}
            Button("Retry") {
                installSkill()
            }
        } message: {
            Text(installErrorMessage)
        }
        .task {
            await loadSkillDetail()
        }
    }

    private func loadSkillDetail() async {
        isLoading = true
        loadError = nil

        skillDetail = await viewModel.loadGitHubSkillDetail(
            owner: repository.owner.login,
            repo: repository.name
        )

        // If loading failed and we have no skill detail, capture the error
        if skillDetail == nil, let error = viewModel.error {
            loadError = error
        }

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
                    // Provide detailed error messages for different failure scenarios
                    installErrorMessage = errorMessage(from: viewModel.error)
                    showInstallErrorAlert = true
                }
            }
        }
    }

    /// Generate user-friendly error messages for installation failures
    private func errorMessage(from error: Error?) -> String {
        guard let error = error else {
            return "Failed to install skill. Please try again."
        }

        let errorDescription = error.localizedDescription.lowercased()

        // Provide specific messages for common failure scenarios
        if errorDescription.contains("network") || errorDescription.contains("connection") {
            return "Network connection failed. Please check your internet connection and try again."
        } else if errorDescription.contains("permission") || errorDescription.contains("denied") {
            return "Permission denied. Please check your file system permissions."
        } else if errorDescription.contains("already exists") || errorDescription.contains("conflict") {
            return "This skill is already installed. Please uninstall it first if you want to reinstall."
        } else if errorDescription.contains("not found") || errorDescription.contains("404") {
            return "Repository not found or SKILL.md file is missing. Please verify the repository."
        } else if errorDescription.contains("git") || errorDescription.contains("clone") {
            return "Git clone failed. Please check the repository URL and try again."
        } else if errorDescription.contains("rate limit") {
            return "GitHub API rate limit exceeded. Please try again later."
        } else {
            return "Failed to install skill: \(error.localizedDescription)"
        }
    }
}
