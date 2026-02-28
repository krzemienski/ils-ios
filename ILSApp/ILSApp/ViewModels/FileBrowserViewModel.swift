import Foundation
import Observation
import ILSShared

/// View model for the file browser, extracting directory loading and file preview
/// from `FileBrowserView` to follow unidirectional data-flow conventions.
@Observable
@MainActor
class FileBrowserViewModel {
    var currentPath: String = "~"
    var entries: [FileEntryResponse] = []
    var isLoading = false
    var errorMessage: String?
    var previewFile: PreviewFile?
    var cachedSortedEntries: [FileEntryResponse] = []

    struct PreviewFile: Identifiable {
        let id = UUID()
        let name: String
        let content: String
    }

    private var client: APIClient?

    func configure(client: APIClient) {
        self.client = client
    }

    func loadDirectory() async {
        guard let client else { return }
        isLoading = true
        errorMessage = nil

        let encodedPath = currentPath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? currentPath

        do {
            let result: [FileEntryResponse] = try await client.get("/system/files?path=\(encodedPath)")
            entries = result
            cachedSortedEntries = Self.sortEntries(result)
        } catch {
            errorMessage = "Failed to load directory: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func previewFileContent(_ name: String) async {
        guard let client else { return }
        let filePath = currentPath == "/" ? "/\(name)" : "\(currentPath)/\(name)"
        let encodedPath = filePath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? filePath

        do {
            let data = try await client.getRawData("/system/files?path=\(encodedPath)&preview=true")
            let content = String(data: data, encoding: .utf8) ?? "Unable to read file"
            let lines = content.components(separatedBy: "\n")
            let truncated = lines.prefix(500).joined(separator: "\n")
            previewFile = PreviewFile(name: name, content: truncated)
        } catch {
            AppLogger.shared.error("Failed to preview file \(name): \(error.localizedDescription)", category: "fileBrowser")
        }
    }

    func navigateToDirectory(_ name: String) {
        if currentPath == "/" {
            currentPath = "/\(name)"
        } else {
            currentPath = "\(currentPath)/\(name)"
        }
        Task { await loadDirectory() }
    }

    /// Sorts entries: directories first, then alphabetical.
    static func sortEntries(_ entries: [FileEntryResponse]) -> [FileEntryResponse] {
        entries.sorted { a, b in
            if a.isDirectory && !b.isDirectory { return true }
            if !a.isDirectory && b.isDirectory { return false }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }
}
