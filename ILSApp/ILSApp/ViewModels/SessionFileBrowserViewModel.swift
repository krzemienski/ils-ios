import Foundation
import Observation
import ILSShared

/// View model for the session file browser sheet.
///
/// Fetches the list of files changed during a Claude Code session and handles
/// file content preview loading, following the project's unidirectional data-flow convention.
@Observable
@MainActor
class SessionFileBrowserViewModel {
    var files: [SessionFileChange] = []
    var searchText: String = ""
    var isLoading = false
    var errorMessage: String?
    var previewFile: PreviewFile?

    /// Filtered file list based on `searchText`. Case-insensitive match against filename or full path.
    var filteredFiles: [SessionFileChange] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return files
        }
        let query = searchText.lowercased()
        return files.filter { change in
            let filename = (change.path as NSString).lastPathComponent.lowercased()
            return filename.contains(query) || change.path.lowercased().contains(query)
        }
    }

    struct PreviewFile: Identifiable {
        let id = UUID()
        let name: String
        let path: String
        let content: String
        let language: String?
    }

    private var client: APIClient?
    private var session: ChatSession?
    private var projectPath: String?

    func configure(client: APIClient, session: ChatSession) {
        self.client = client
        self.session = session
    }

    func loadFiles() async {
        guard let client,
              let session,
              let encodedProjectPath = session.encodedProjectPath,
              let claudeSessionId = session.claudeSessionId else {
            errorMessage = "Session does not have file tracking information"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response: SessionFilesResponse = try await client.get(
                "/sessions/transcript/\(encodedProjectPath)/\(claudeSessionId)/files"
            )
            files = response.files
            projectPath = response.projectPath
        } catch {
            errorMessage = "Failed to load changed files: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func previewFileContent(change: SessionFileChange) async {
        guard let client else { return }

        let absolutePath: String
        if let base = projectPath, !change.path.hasPrefix("/") {
            absolutePath = base.hasSuffix("/")
                ? "\(base)\(change.path)"
                : "\(base)/\(change.path)"
        } else {
            absolutePath = change.path
        }

        let encodedPath = absolutePath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? absolutePath

        do {
            let data = try await client.getRawData("/system/files?path=\(encodedPath)&preview=true")
            let content = String(data: data, encoding: .utf8) ?? "Unable to read file"
            let lines = content.components(separatedBy: "\n")
            let truncated = lines.prefix(500).joined(separator: "\n")
            let filename = (change.path as NSString).lastPathComponent
            previewFile = PreviewFile(
                name: filename,
                path: change.path,
                content: truncated,
                language: change.language
            )
        } catch {
            AppLogger.shared.error(
                "Failed to preview file \(change.path): \(error.localizedDescription)",
                category: "sessionFileBrowser"
            )
        }
    }
}
