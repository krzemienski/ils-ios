import SwiftUI
import ILSShared

/// File browser with breadcrumb navigation.
/// Starts at ~/ and allows navigating into directories.
struct FileBrowserView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(AppState.self) var appState

    @State private var currentPath: String = "~"
    @State private var entries: [FileEntryResponse] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var previewFile: PreviewFile?

    struct PreviewFile: Identifiable {
        let id = UUID()
        let name: String
        let content: String
    }

    var body: some View {
        VStack(spacing: 0) {
            // Breadcrumb
            breadcrumbBar

            Divider()
                .background(theme.bgTertiary)

            // File list
            if isLoading {
                Spacer()
                ProgressView()
                    .tint(theme.entitySystem)
                Spacer()
            } else if let error = errorMessage {
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
                        Task { await loadDirectory() }
                    }
                    .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)
                }
                .padding()
                Spacer()
            } else if entries.isEmpty {
                Spacer()
                Text("Empty directory")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(sortedEntries, id: \.name) { entry in
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
            await loadDirectory()
        }
        .sheet(item: $previewFile) { file in
            filePreviewSheet(file)
                .presentationBackground(theme.bgPrimary)
        }
    }

    // MARK: - Breadcrumb

    private var pathComponents: [(label: String, path: String)] {
        let parts = currentPath.split(separator: "/", omittingEmptySubsequences: true)
        var result: [(String, String)] = []

        if currentPath.hasPrefix("~") {
            result.append(("~", "~"))
            var accumulated = "~"
            for part in parts.dropFirst(0).enumerated() {
                if part.offset == 0 && part.element == "~" { continue }
                accumulated += "/\(part.element)"
                result.append((String(part.element), accumulated))
            }
            if result.count == 1 && currentPath == "~" {
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
                ForEach(Array(pathComponents.enumerated()), id: \.offset) { index, component in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(theme.textTertiary)
                    }

                    Button {
                        currentPath = component.path
                        Task { await loadDirectory() }
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

    private var sortedEntries: [FileEntryResponse] {
        entries.sorted { a, b in
            if a.isDirectory && !b.isDirectory { return true }
            if !a.isDirectory && b.isDirectory { return false }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    private func fileRow(_ entry: FileEntryResponse) -> some View {
        Button {
            if entry.isDirectory {
                navigateToDirectory(entry.name)
            } else {
                Task { await previewFileContent(entry.name) }
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

    private func filePreviewSheet(_ file: PreviewFile) -> some View {
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
                        previewFile = nil
                    }
                    .foregroundStyle(theme.entitySystem)
                }
            }
        }
    }

    // MARK: - Navigation & Loading

    private func navigateToDirectory(_ name: String) {
        if currentPath == "/" {
            currentPath = "/\(name)"
        } else {
            currentPath = "\(currentPath)/\(name)"
        }
        Task { await loadDirectory() }
    }

    private func loadDirectory() async {
        isLoading = true
        errorMessage = nil

        let encodedPath = currentPath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? currentPath

        do {
            let result: [FileEntryResponse] = try await appState.apiClient.get("/system/files?path=\(encodedPath)")
            entries = result
        } catch {
            errorMessage = "Failed to load directory: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func previewFileContent(_ name: String) async {
        let filePath = currentPath == "/" ? "/\(name)" : "\(currentPath)/\(name)"
        let encodedPath = filePath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? filePath
        guard let url = URL(string: "\(appState.serverURL)/api/v1/system/files?path=\(encodedPath)&preview=true") else { return }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }
            let content = String(data: data, encoding: .utf8) ?? "Unable to read file"
            let lines = content.components(separatedBy: "\n")
            let truncated = lines.prefix(500).joined(separator: "\n")
            previewFile = PreviewFile(name: name, content: truncated)
        } catch {
            // Silently fail for preview
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
