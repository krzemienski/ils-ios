import SwiftUI
import ILSShared

/// File browser with breadcrumb navigation and text-file preview.
///
/// Starts at `~/` and allows navigating into subdirectories. Directories sort
/// before files; both groups are ordered alphabetically. Tapping a file opens a
/// read-only text preview sheet; tapping a directory updates the path and
/// reloads the listing via the view model.
///
/// ## Topics
/// ### State
/// - ``viewModel`` - Manages directory loading and file preview via `FileBrowserViewModel`
struct FileBrowserView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(AppState.self) var appState

    @State private var viewModel = FileBrowserViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Breadcrumb
            breadcrumbBar

            Divider()
                .background(theme.bgTertiary)

            // File list
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
                        Task { await viewModel.loadDirectory() }
                    }
                    .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)
                }
                .padding()
                Spacer()
            } else if viewModel.entries.isEmpty {
                Spacer()
                Text("Empty directory")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.cachedSortedEntries, id: \.name) { entry in
                            fileRow(entry)
                            Divider()
                                .background(theme.bgTertiary)
                        }
                    }
                }
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle("Files")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .task {
            viewModel.configure(client: appState.apiClient)
            await viewModel.loadDirectory()
        }
        .sheet(item: $viewModel.previewFile) { file in
            filePreviewSheet(file)
                .presentationBackground(theme.bgPrimary)
        }
    }

    // MARK: - Breadcrumb

    private var pathComponents: [(label: String, path: String)] {
        let parts = viewModel.currentPath.split(separator: "/", omittingEmptySubsequences: true)
        var result: [(String, String)] = []

        if viewModel.currentPath.hasPrefix("~") {
            result.append(("~", "~"))
            var accumulated = "~"
            for part in parts.dropFirst(0).enumerated() {
                if part.offset == 0 && part.element == "~" { continue }
                accumulated += "/\(part.element)"
                result.append((String(part.element), accumulated))
            }
            if result.count == 1 && viewModel.currentPath == "~" {
                return result
            }
        } else {
            result.append(("/", "/"))
            var accumulated = ""
            for part in parts {
                accumulated += "/\(part)"
                result.append((String(part), accumulated))
            }
        }
        return result
    }

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacingXS) {
                // SPERF-MED-6: Use indices for stable ForEach identity.
                ForEach(pathComponents.indices, id: \.self) { index in
                    let component = pathComponents[index]
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(theme.textTertiary)
                    }

                    Button {
                        viewModel.currentPath = component.path
                        Task { await viewModel.loadDirectory() }
                    } label: {
                        Text(component.label)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(
                                index == pathComponents.count - 1
                                    ? theme.entitySystem
                                    : theme.textSecondary
                            )
                    }
                }
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingSM)
        }
        .background(theme.bgSecondary)
    }

    // MARK: - File Row

    private func fileRow(_ entry: FileEntryResponse) -> some View {
        Button {
            if entry.isDirectory {
                viewModel.navigateToDirectory(entry.name)
            } else {
                Task { await viewModel.previewFileContent(entry.name) }
            }
        } label: {
            HStack(spacing: theme.spacingMD) {
                Image(systemName: entry.isDirectory ? "folder.fill" : "doc.text")
                    .foregroundStyle(entry.isDirectory ? theme.entitySystem : theme.textTertiary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    if !entry.isDirectory {
                        Text(formatFileSize(entry.size))
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                }

                Spacer()

                if entry.isDirectory {
                    Image(systemName: "chevron.right")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingSM)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - File Preview Sheet

    private func filePreviewSheet(_ file: FileBrowserViewModel.PreviewFile) -> some View {
        NavigationStack {
            ScrollView {
                Text(file.content)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(theme.spacingMD)
            }
            .background(theme.bgPrimary)
            .navigationTitle(file.name)
            #if os(iOS)
            .inlineNavigationBarTitle()
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        viewModel.previewFile = nil
                    }
                    .foregroundStyle(theme.entitySystem)
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatFileSize(_ bytes: UInt64) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        let gb = mb / 1024

        if gb >= 1 { return String(format: "%.1f GB", gb) }
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        if kb >= 1 { return String(format: "%.0f KB", kb) }
        return "\(bytes) B"
    }
}
