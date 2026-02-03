import Foundation
import Vapor
import ILSShared

/// Service for scanning external Claude Code sessions
struct SessionScanningService {
    private let fileManager = FileManager.default

    /// Home directory path
    var homeDirectory: String {
        fileManager.homeDirectoryForCurrentUser.path
    }

    /// Claude directory path
    var claudeDirectory: String {
        "\(homeDirectory)/.claude"
    }

    /// Claude projects directory for session scanning
    var claudeProjectsPath: String {
        "\(claudeDirectory)/projects"
    }

    // MARK: - Session Scanning

    /// Scan for external Claude Code sessions
    func scanExternalSessions() throws -> [ExternalSession] {
        var sessions: [ExternalSession] = []

        guard fileManager.fileExists(atPath: claudeProjectsPath) else {
            return sessions
        }

        let contents = try fileManager.contentsOfDirectory(atPath: claudeProjectsPath)

        for item in contents {
            let projectPath = "\(claudeProjectsPath)/\(item)"
            var isDirectory: ObjCBool = false

            if fileManager.fileExists(atPath: projectPath, isDirectory: &isDirectory), isDirectory.boolValue {
                // Look for session files
                let projectContents = try? fileManager.contentsOfDirectory(atPath: projectPath)
                for sessionFile in projectContents ?? [] {
                    if sessionFile.hasSuffix(".json") {
                        let sessionId = sessionFile.replacingOccurrences(of: ".json", with: "")
                        let fullPath = "\(projectPath)/\(sessionFile)"

                        // Get file modification date
                        let attrs = try? fileManager.attributesOfItem(atPath: fullPath)
                        let modDate = attrs?[.modificationDate] as? Date

                        sessions.append(ExternalSession(
                            claudeSessionId: sessionId,
                            projectPath: item,
                            source: .external,
                            lastActiveAt: modDate
                        ))
                    }
                }
            }
        }

        return sessions
    }
}
