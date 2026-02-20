import Foundation
import Vapor
import ILSShared
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

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

            let data: Data
            let index: SessionsIndex
            do {
                data = try Data(contentsOf: URL(fileURLWithPath: indexPath))
                index = try JSONDecoder().decode(SessionsIndex.self, from: data)
            } catch {
                // Log and skip malformed session index files
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
        // Sanitize path components to prevent directory traversal
        try PathSanitizer.validateComponent(encodedProjectPath)
        try PathSanitizer.validateComponent(sessionId)

        let transcriptPath = "\(claudeProjectsPath)/\(encodedProjectPath)/\(sessionId).jsonl"

        // Verify resolved path stays within claude projects directory
        _ = try PathSanitizer.validateWithinBase(transcriptPath, baseDirectory: claudeProjectsPath)

        guard fileManager.fileExists(atPath: transcriptPath) else {
            throw Vapor.Abort(.notFound, reason: "Transcript not found")
        }

        let content = try String(contentsOfFile: transcriptPath, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

        var messages: [Message] = []
        // Use a deterministic UUID based on session so IDs are stable
        let sessionUUID = UUID(uuidString: sessionId) ?? UUID()

        let jsonDecoder = JSONDecoder()

        for line in lines {
            guard let lineData = line.data(using: .utf8) else {
                continue
            }

            let entry: TranscriptEntry
            do {
                entry = try jsonDecoder.decode(TranscriptEntry.self, from: lineData)
            } catch {
                // Skip malformed JSONL lines — common in partial writes
                continue
            }

            guard entry.type == "user" || entry.type == "assistant" else {
                continue
            }

            guard let messageObj = entry.message else {
                continue
            }

            let role: MessageRole = messageObj.role == "user" ? .user : .assistant
            var textContent = ""
            var toolCallsJSON: String?

            switch messageObj.content {
            case .string(let stringContent):
                textContent = stringContent
            case .blocks(let blocks):
                var textParts: [String] = []
                var toolCalls: [TranscriptToolCall] = []

                for block in blocks {
                    switch block.type {
                    case "text":
                        if let text = block.text {
                            textParts.append(text)
                        }
                    case "tool_use":
                        toolCalls.append(TranscriptToolCall(
                            id: block.id ?? "",
                            name: block.name ?? "",
                            type: "tool_use"
                        ))
                    default:
                        break
                    }
                }

                textContent = textParts.joined(separator: "\n")
                if !toolCalls.isEmpty {
                    do {
                        let tcData = try JSONEncoder().encode(toolCalls)
                        toolCallsJSON = String(data: tcData, encoding: .utf8)
                    } catch {
                        // Tool call serialization is non-critical; skip
                    }
                }
            case .none:
                continue
            }

            // Skip empty messages and internal command messages
            let trimmed = textContent.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            // Parse timestamp if available
            let timestamp: Date? = entry.timestamp.flatMap { parseISO8601Date($0) }
            let messageId = UUID(uuidString: entry.uuid ?? "") ?? UUID()

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

// MARK: - Transcript JSONL Codable Types

/// Top-level entry in a Claude session JSONL transcript file.
private struct TranscriptEntry: Decodable {
    let type: String
    let message: TranscriptMessage?
    let timestamp: String?
    let uuid: String?
}

/// Message object within a transcript entry.
private struct TranscriptMessage: Decodable {
    let role: String
    let content: TranscriptContent?
}

/// Content can be either a plain string (user messages) or an array of content blocks (assistant messages).
private enum TranscriptContent: Decodable {
    case string(String)
    case blocks([TranscriptContentBlock])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .string(str)
        } else if let blocks = try? container.decode([TranscriptContentBlock].self) {
            self = .blocks(blocks)
        } else {
            self = .blocks([])
        }
    }
}

/// A single content block within an assistant message (text, tool_use, etc.).
private struct TranscriptContentBlock: Decodable {
    let type: String
    let text: String?
    let id: String?
    let name: String?
}

/// Codable tool call for JSON serialization in transcript parsing.
private struct TranscriptToolCall: Codable {
    let id: String
    let name: String
    let type: String
}
