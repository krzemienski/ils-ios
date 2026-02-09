import Foundation
import Vapor
import ILSShared
import CryptoKit

/// Service for external Claude Code session scanning and transcript reading.
///
/// Scans `~/.claude/projects/` for sessions-index.json files and reads JSONL transcript files.
/// Each project directory is URL-encoded and contains session metadata + transcript files.
struct SessionFileService {
    private let fileManager = FileManager.default

    /// Home directory path
    var homeDirectory: String {
        fileManager.homeDirectoryForCurrentUser.path
    }

    /// Claude configuration directory path (`~/.claude`)
    var claudeDirectory: String {
        "\(homeDirectory)/.claude"
    }

    /// Claude projects directory path (`~/.claude/projects`)
    var claudeProjectsPath: String {
        "\(claudeDirectory)/projects"
    }

    // MARK: - Date Parsing

    /// Flexible ISO8601 date formatter that handles fractional seconds
    private static let flexibleISO8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Fallback ISO8601 formatter without fractional seconds
    private static let fallbackISO8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Parse an ISO8601 date string, handling both with and without fractional seconds.
    /// - Parameter string: ISO8601 date string
    /// - Returns: Parsed Date or nil if invalid
    private func parseISO8601Date(_ string: String) -> Date? {
        Self.flexibleISO8601Formatter.date(from: string)
            ?? Self.fallbackISO8601Formatter.date(from: string)
    }

    // MARK: - Data Structures

    /// Structure matching sessions-index.json from ~/.claude/projects/
    struct SessionsIndex: Codable {
        let version: Int
        let entries: [SessionEntry]
    }

    struct SessionEntry: Codable {
        let sessionId: String
        let projectPath: String
        let summary: String?
        let created: String   // ISO8601 string — decoded manually for fractional seconds
        let modified: String  // ISO8601 string
        let fullPath: String?
        let firstPrompt: String?
        let messageCount: Int?
        let gitBranch: String?
        let isSidechain: Bool?
        let fileMtime: Int64?
    }

    // MARK: - Session Scanning

    /// Scan for external Claude Code sessions by reading sessions-index.json files from `~/.claude/projects/`.
    /// - Returns: Array of ExternalSession objects sorted by last active date
    func scanExternalSessions() throws -> [ExternalSession] {
        var sessions: [ExternalSession] = []

        guard fileManager.fileExists(atPath: claudeProjectsPath) else {
            return sessions
        }

        let contents = try fileManager.contentsOfDirectory(atPath: claudeProjectsPath)

        for encodedDir in contents {
            let projectDirPath = "\(claudeProjectsPath)/\(encodedDir)"
            var isDirectory: ObjCBool = false

            guard fileManager.fileExists(atPath: projectDirPath, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                continue
            }

            let indexPath = "\(projectDirPath)/sessions-index.json"
            guard fileManager.fileExists(atPath: indexPath) else {
                continue
            }

            guard let data = try? Data(contentsOf: URL(fileURLWithPath: indexPath)),
                  let index = try? JSONDecoder().decode(SessionsIndex.self, from: data) else {
                continue
            }

            let projectName = index.entries.first.map {
                URL(fileURLWithPath: $0.projectPath).lastPathComponent
            }

            for entry in index.entries {
                let createdDate = parseISO8601Date(entry.created)
                let modifiedDate = parseISO8601Date(entry.modified)

                // Use summary as name, fall back to firstPrompt truncated
                let displayName: String? = entry.summary
                    ?? entry.firstPrompt.flatMap { prompt in
                        let clean = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                        return clean.isEmpty || clean == "No prompt" ? nil : String(clean.prefix(80))
                    }

                sessions.append(ExternalSession(
                    claudeSessionId: entry.sessionId,
                    name: displayName,
                    projectPath: entry.projectPath,
                    encodedProjectPath: encodedDir,
                    projectName: projectName,
                    source: .external,
                    lastActiveAt: modifiedDate,
                    createdAt: createdDate,
                    messageCount: entry.messageCount,
                    firstPrompt: entry.firstPrompt,
                    summary: entry.summary,
                    gitBranch: entry.gitBranch
                ))
            }
        }

        // Sort by last active date, most recent first
        sessions.sort { ($0.lastActiveAt ?? .distantPast) > ($1.lastActiveAt ?? .distantPast) }

        return sessions
    }

    // MARK: - Deterministic UUID

    /// Generate a deterministic UUID from a Claude session ID using SHA256.
    /// This ensures the same external session always gets the same UUID across loads.
    private func deterministicUUID(from claudeSessionId: String) -> UUID {
        let input = "ils-external-session:\(claudeSessionId)"
        let hash = SHA256.hash(data: Data(input.utf8))
        var bytes = Array(hash.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x40  // version 4
        bytes[8] = (bytes[8] & 0x3F) | 0x80  // variant 1 (RFC 4122)
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3],
                           bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11],
                           bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    // MARK: - ChatSession Conversion

    /// Convert an ExternalSession to a ChatSession with a deterministic UUID.
    private func toChatSession(_ ext: ExternalSession) -> ChatSession {
        ChatSession(
            id: deterministicUUID(from: ext.claudeSessionId),
            claudeSessionId: ext.claudeSessionId,
            name: ext.name ?? ext.summary,
            projectName: ext.projectName,
            model: "sonnet",
            permissionMode: .default,
            status: .completed,
            messageCount: ext.messageCount ?? 0,
            source: .external,
            createdAt: ext.createdAt ?? ext.lastActiveAt ?? Date(),
            lastActiveAt: ext.lastActiveAt ?? Date(),
            encodedProjectPath: ext.encodedProjectPath,
            firstPrompt: ext.firstPrompt
        )
    }

    /// Scan external sessions and return as ChatSession objects with deterministic IDs.
    /// - Returns: Array of ChatSession objects sorted by lastActiveAt descending
    func scanExternalSessionsAsChatSessions() throws -> [ChatSession] {
        let externals = try scanExternalSessions()
        return externals.map { toChatSession($0) }
    }

    // MARK: - Transcript Reading

    /// Read messages from a session's JSONL transcript file.
    ///
    /// Parses `~/.claude/projects/{encodedProjectPath}/{sessionId}.jsonl` and extracts
    /// user and assistant messages with text content and tool calls.
    ///
    /// - Parameters:
    ///   - encodedProjectPath: URL-encoded project directory name
    ///   - sessionId: Session UUID
    ///   - limit: Maximum number of messages to return (default: 100)
    ///   - offset: Number of messages to skip (default: 0)
    /// - Returns: Array of Message objects
    func readTranscriptMessages(encodedProjectPath: String, sessionId: String, limit: Int = 100, offset: Int = 0) throws -> [Message] {
        let transcriptPath = "\(claudeProjectsPath)/\(encodedProjectPath)/\(sessionId).jsonl"

        guard fileManager.fileExists(atPath: transcriptPath) else {
            throw Vapor.Abort(.notFound, reason: "Transcript not found")
        }

        let content = try String(contentsOfFile: transcriptPath, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

        var messages: [Message] = []
        // Use a deterministic UUID based on session so IDs are stable
        let sessionUUID = UUID(uuidString: sessionId) ?? UUID()

        for line in lines {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            guard let type = json["type"] as? String,
                  type == "user" || type == "assistant" else {
                continue
            }

            guard let messageObj = json["message"] as? [String: Any],
                  let roleStr = messageObj["role"] as? String else {
                continue
            }

            let role: MessageRole = roleStr == "user" ? .user : .assistant
            var textContent = ""
            var toolCallsJSON: String?

            let rawContent = messageObj["content"]

            if let stringContent = rawContent as? String {
                // User messages can be plain strings
                textContent = stringContent
            } else if let blocks = rawContent as? [[String: Any]] {
                // Array of content blocks (text, tool_use, etc.)
                var textParts: [String] = []
                var toolCalls: [[String: Any]] = []

                for block in blocks {
                    guard let blockType = block["type"] as? String else { continue }
                    if blockType == "text", let text = block["text"] as? String {
                        textParts.append(text)
                    } else if blockType == "tool_use" {
                        let toolCall: [String: Any] = [
                            "id": block["id"] as? String ?? "",
                            "name": block["name"] as? String ?? "",
                            "type": "tool_use"
                        ]
                        toolCalls.append(toolCall)
                    }
                }

                textContent = textParts.joined(separator: "\n")
                if !toolCalls.isEmpty,
                   let tcData = try? JSONSerialization.data(withJSONObject: toolCalls),
                   let tcString = String(data: tcData, encoding: .utf8) {
                    toolCallsJSON = tcString
                }
            }

            // Skip empty messages and internal command messages
            let trimmed = textContent.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            // Parse timestamp if available
            let timestamp: Date?
            if let ts = json["timestamp"] as? String {
                timestamp = parseISO8601Date(ts)
            } else {
                timestamp = nil
            }

            let messageId = UUID(uuidString: (json["uuid"] as? String) ?? "") ?? UUID()

            let message = Message(
                id: messageId,
                sessionId: sessionUUID,
                role: role,
                content: textContent,
                toolCalls: toolCallsJSON,
                createdAt: timestamp ?? Date(),
                updatedAt: timestamp ?? Date()
            )

            messages.append(message)
        }

        // Apply pagination
        let total = messages.count
        let start = min(offset, total)
        let end = min(start + limit, total)
        return Array(messages[start..<end])
    }
}
