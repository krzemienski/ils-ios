import SwiftUI
import ILSShared

/// File browser showing all files changed during a Claude Code session.
///
/// Displays a searchable list of files created, modified, or deleted during the session.
/// Each row shows a change-type icon (created/modified/deleted), the filename, the relative
/// path, and an optional language badge. Tapping a file opens a syntax-highlighted preview
/// sheet via ``SessionFilePreviewView``.
///
/// ## Topics
/// ### State
/// - ``viewModel`` - Manages file list loading, search filtering, and content preview via `SessionFileBrowserViewModel`
struct SessionFileBrowserView: View {
    let session: ChatSession
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(AppState.self) var appState

    @State private var viewModel = SessionFileBrowserViewModel()

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            Divider()
                .background(theme.bgTertiary)

            if viewModel.isLoading {
                Spacer()
                ProgressView()
                    .tint(theme.entitySystem)
                Spacer()
            } else if let error = viewModel.errorMessage {
                Spacer()
                VStack(spacing: theme.spacingSM) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: theme.fontTitle2, design: theme.fontDesign))
                        .foregroundStyle(theme.error)
                    Text(error)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await viewModel.loadFiles() }
                    }
                    .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)
                }
                .padding()
                Spacer()
            } else if viewModel.filteredFiles.isEmpty {
                Spacer()
                Text(viewModel.files.isEmpty ? "No changed files found" : "No files match your search")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.filteredFiles) { change in
                            fileRow(change)
                            Divider()
                                .background(theme.bgTertiary)
                        }
                    }
                }
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle("Changed Files")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .task {
            viewModel.configure(client: appState.apiClient, session: session)
            await viewModel.loadFiles()
        }
        .sheet(item: $viewModel.previewFile) { file in
            SessionFilePreviewView(file: file)
                .presentationBackground(theme.bgPrimary)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.textTertiary)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))

            TextField("Search files…", text: $viewModel.searchText)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.textTertiary)
                }
            }

            Spacer()

            let count = viewModel.filteredFiles.count
            Text("\(count) file\(count == 1 ? "" : "s")")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(.horizontal, theme.spacingMD)
        .padding(.vertical, theme.spacingSM)
        .background(theme.bgSecondary)
    }

    // MARK: - File Row

    private func fileRow(_ change: SessionFileChange) -> some View {
        Button {
            Task { await viewModel.previewFileContent(change: change) }
        } label: {
            HStack(spacing: theme.spacingMD) {
                changeTypeIcon(for: change.changeType)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text((change.path as NSString).lastPathComponent)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    Text(change.path)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                if let language = change.language {
                    languageBadge(language)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingSM)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func changeTypeIcon(for changeType: FileChangeType) -> some View {
        switch changeType {
        case .created:
            Image(systemName: "doc.badge.plus")
                .foregroundStyle(theme.success)
        case .modified:
            Image(systemName: "pencil.circle")
                .foregroundStyle(theme.warning)
        case .deleted:
            Image(systemName: "trash")
                .foregroundStyle(theme.error)
        }
    }

    private func languageBadge(_ language: String) -> some View {
        Text(language)
            .font(.system(size: 10, weight: .medium, design: theme.fontDesign))
            .foregroundStyle(theme.entitySystem)
            .padding(.horizontal, theme.spacingXS)
            .padding(.vertical, 2)
            .background(theme.entitySystem.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
