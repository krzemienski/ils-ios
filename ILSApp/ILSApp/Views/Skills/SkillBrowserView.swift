import SwiftUI
import ILSShared

struct SkillBrowserView: View {
    @ObservedObject var viewModel: SkillsViewModel
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if let error = viewModel.error, viewModel.isSearchingGitHub {
                ErrorStateView(error: error) {
                    await viewModel.searchGitHubSkills(query: searchText)
                }
            } else if viewModel.githubSkills.isEmpty && !viewModel.isSearchingGitHub {
                if searchText.isEmpty {
                    EmptyStateView(
                        title: "Search GitHub",
                        systemImage: "magnifyingglass",
                        description: "Search for Claude Code skills on GitHub"
                    )
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            } else {
                ForEach(viewModel.githubSkills, id: \.id) { repo in
                    NavigationLink {
                        GitHubSkillDetailView(
                            repository: repo,
                            viewModel: viewModel
                        )
                    } label: {
                        GitHubSkillRowView(repository: repo, viewModel: viewModel)
                    }
                }
            }
        }
        .navigationTitle("Browse Skills")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search GitHub skills...")
        .onChange(of: searchText) { _, newValue in
            Task {
                // Debounce search to avoid too many API calls
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                if searchText == newValue {
                    await viewModel.searchGitHubSkills(query: newValue)
                }
            }
        }
        .overlay {
            if viewModel.isSearchingGitHub {
                ProgressView("Searching GitHub...")
            }
        }
    }
}

struct GitHubSkillRowView: View {
    let repository: GitHubRepository
    @ObservedObject var viewModel: SkillsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: ILSTheme.spacingXS) {
            // Repository name
            HStack {
                Text(repository.name)
                    .font(ILSTheme.headlineFont)

                Spacer()

                // Installation status indicator
                if viewModel.isRepositoryInstalling(repository) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.trailing, ILSTheme.spacingXS)
                } else if viewModel.isRepositoryInstalled(repository) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.body)
                        .padding(.trailing, ILSTheme.spacingXS)
                }

                // Star count
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                    Text("\(repository.stargazersCount)")
                        .font(.caption)
                        .foregroundColor(ILSTheme.secondaryText)
                }
            }

            // Description
            if let description = repository.description {
                Text(description)
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.secondaryText)
                    .lineLimit(2)
            }

            // Topics/Tags
            if let topics = repository.topics, !topics.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ILSTheme.spacingXS) {
                        ForEach(topics.prefix(5), id: \.self) { topic in
                            Text(topic)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ILSTheme.accent.opacity(0.15))
                                .foregroundColor(ILSTheme.accent)
                                .cornerRadius(ILSTheme.cornerRadiusS)
                        }
                    }
                }
            }

            // Metadata: owner and last updated
            HStack(spacing: ILSTheme.spacingXS) {
                Text(repository.owner.login)
                    .font(.caption2)
                    .foregroundColor(ILSTheme.tertiaryText)

                Text("•")
                    .font(.caption2)
                    .foregroundColor(ILSTheme.tertiaryText)

                if let language = repository.language {
                    Text(language)
                        .font(.caption2)
                        .foregroundColor(ILSTheme.tertiaryText)

                    Text("•")
                        .font(.caption2)
                        .foregroundColor(ILSTheme.tertiaryText)
                }

                Text(formatDate(repository.updatedAt))
                    .font(.caption2)
                    .foregroundColor(ILSTheme.tertiaryText)
            }
        }
        .padding(.vertical, ILSTheme.spacingXS)
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return "Unknown"
        }

        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .hour, .minute], from: date, to: now)

        if let days = components.day, days > 0 {
            if days == 1 {
                return "Updated yesterday"
            } else if days < 30 {
                return "Updated \(days)d ago"
            } else if days < 365 {
                let months = days / 30
                return "Updated \(months)mo ago"
            } else {
                let years = days / 365
                return "Updated \(years)y ago"
            }
        } else if let hours = components.hour, hours > 0 {
            return "Updated \(hours)h ago"
        } else if let minutes = components.minute, minutes > 0 {
            return "Updated \(minutes)m ago"
        } else {
            return "Updated just now"
        }
    }
}

