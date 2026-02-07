import SwiftUI
import ILSShared

/// File browser with breadcrumb navigation.
/// Starts at ~/ and allows navigating into directories.
struct FileBrowserView: View {
    let baseURL: String

    @State private var currentPath: String = "~"
    @State private var entries: [FileEntryResponse] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var previewFile: PreviewFile?

    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

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
                .background(ILSTheme.bg3)

            // File list
            if isLoading {
                Spacer()
                ProgressView()
                    .tint(EntityType.system.color)
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: ILSTheme.spaceS) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(ILSTheme.error)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(ILSTheme.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await loadDirectory() }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding()
                Spacer()
            } else if entries.isEmpty {
                Spacer()
                Text("Empty directory")
                    .font(.subheadline)
                    .foregroundColor(ILSTheme.textTertiary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(sortedEntries, id: \.name) { entry in
                            fileRow(entry)
                            Divider()
                                .background(ILSTheme.bg3)
                        }
                    }
                }
            }
        }
        .background(ILSTheme.bg0)
        .navigationTitle("Files")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDirectory()
        }
        .sheet(item: $previewFile) { file in
            filePreviewSheet(file)
                .presentationBackground(Color.black)
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
            HStack(spacing: ILSTheme.spaceXS) {
                ForEach(Array(pathComponents.enumerated()), id: \.offset) { index, component in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(ILSTheme.textTertiary)
                    }

                    Button {
                        currentPath = component.path
                        Task { await loadDirectory() }
                    } label: {
                        Text(component.label)
                            .font(.caption.weight(index == pathComponents.count - 1 ? .semibold : .regular))
                            .foregroundColor(
                                index == pathComponents.count - 1
                                    ? EntityType.system.color
                                    : ILSTheme.textSecondary
                            )
                    }
                }
            }
            .padding(.horizontal, ILSTheme.spaceL)
            .padding(.vertical, ILSTheme.spaceS)
        }
        .background(ILSTheme.bg1)
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
            HStack(spacing: ILSTheme.spaceM) {
                Image(systemName: entry.isDirectory ? "folder.fill" : "doc.text")
                    .foregroundColor(entry.isDirectory ? EntityType.system.color : ILSTheme.textTertiary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.subheadline)
                        .foregroundColor(ILSTheme.textPrimary)
                        .lineLimit(1)

                    if !entry.isDirectory {
                        Text(formatFileSize(entry.size))
                            .font(.caption2)
                            .foregroundColor(ILSTheme.textTertiary)
                    }
                }

                Spacer()

                if entry.isDirectory {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(ILSTheme.textTertiary)
                }
            }
            .padding(.horizontal, ILSTheme.spaceL)
            .padding(.vertical, ILSTheme.spaceS)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - File Preview Sheet

    private func filePreviewSheet(_ file: PreviewFile) -> some View {
        NavigationStack {
            ScrollView {
                Text(file.content)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(ILSTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(ILSTheme.spaceM)
            }
            .background(ILSTheme.bg0)
            .navigationTitle(file.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        previewFile = nil
                    }
                    .foregroundColor(EntityType.system.color)
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
        guard let url = URL(string: "\(baseURL)/api/v1/system/files?path=\(encodedPath)") else {
            errorMessage = "Invalid path"
            isLoading = false
            return
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                errorMessage = "Server returned an error"
                isLoading = false
                return
            }
            entries = try decoder.decode([FileEntryResponse].self, from: data)
        } catch {
            errorMessage = "Failed to load directory: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func previewFileContent(_ name: String) async {
        let filePath = currentPath == "/" ? "/\(name)" : "\(currentPath)/\(name)"
        let encodedPath = filePath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? filePath
        guard let url = URL(string: "\(baseURL)/api/v1/system/files?path=\(encodedPath)&preview=true") else { return }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }
            let content = String(data: data, encoding: .utf8) ?? "Unable to read file"
            // Limit to first 500 lines
            let lines = content.components(separatedBy: "\n")
            let truncated = lines.prefix(500).joined(separator: "\n")
            previewFile = PreviewFile(name: name, content: truncated)
        } catch {
            // Silently fail
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
