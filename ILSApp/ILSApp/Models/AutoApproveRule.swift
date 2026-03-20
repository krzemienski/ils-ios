import Foundation
import ILSShared

// MARK: - AutoApproveRule

/// A user-configured rule for automatically allowing or denying permission requests.
///
/// Rules are evaluated in priority order (lower number = higher priority). The first matching
/// rule determines the outcome. A rule matches when all non-nil criteria fields match the
/// incoming permission request.
struct AutoApproveRule: Codable, Identifiable, Sendable, Hashable {
    /// Unique identifier for this rule.
    let id: UUID
    /// The tool this rule applies to (e.g. "Bash", "Read", "Write", "Edit", "Glob", "Grep").
    /// A nil value means the rule applies to any tool.
    var toolName: String?
    /// A glob-style path pattern this rule applies to (e.g. "/src/**").
    /// A nil value means any path is matched.
    var pathGlob: String?
    /// A command prefix this rule applies to (e.g. "git status").
    /// A nil value means any command is matched.
    var commandPrefix: String?
    /// The MCP server name this rule applies to for MCP tool requests.
    /// A nil value means any MCP server is matched.
    var mcpServer: String?
    /// Action to take when this rule matches: allow or deny.
    /// Defaults to `.allow` for backward compatibility with existing stored rules.
    var action: PermissionPolicyAction
    /// Whether this rule is currently active.
    var isEnabled: Bool
    /// The project this rule is scoped to. A nil value means the rule is global.
    var projectId: UUID?
    /// An optional human-readable description of the rule's intent.
    var note: String?
    /// Evaluation order — lower numbers are evaluated first. Default is 100.
    var priority: Int
    /// When this rule was created.
    var createdAt: Date

    init(
        id: UUID = UUID(),
        toolName: String? = nil,
        pathGlob: String? = nil,
        commandPrefix: String? = nil,
        mcpServer: String? = nil,
        action: PermissionPolicyAction = .allow,
        isEnabled: Bool = true,
        projectId: UUID? = nil,
        note: String? = nil,
        priority: Int = 100,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.toolName = toolName
        self.pathGlob = pathGlob
        self.commandPrefix = commandPrefix
        self.mcpServer = mcpServer
        self.action = action
        self.isEnabled = isEnabled
        self.projectId = projectId
        self.note = note
        self.priority = priority
        self.createdAt = createdAt
    }

    // MARK: - Codable (Backward Compatibility)

    enum CodingKeys: String, CodingKey {
        case id, toolName, pathGlob, commandPrefix, mcpServer, action, isEnabled, projectId, note, priority, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        toolName = try container.decodeIfPresent(String.self, forKey: .toolName)
        pathGlob = try container.decodeIfPresent(String.self, forKey: .pathGlob)
        commandPrefix = try container.decodeIfPresent(String.self, forKey: .commandPrefix)
        mcpServer = try container.decodeIfPresent(String.self, forKey: .mcpServer)
        // Default to .allow for backward compatibility with existing stored rules that lack this field
        action = try container.decodeIfPresent(PermissionPolicyAction.self, forKey: .action) ?? .allow
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        projectId = try container.decodeIfPresent(UUID.self, forKey: .projectId)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        // Default to 100 for backward compatibility with existing stored rules that lack this field
        priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 100
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    // MARK: - Destructive Operation Detection

    /// Returns true if this rule is considered destructive.
    ///
    /// A rule is destructive if:
    /// - Its action is `.deny` (silently blocking operations without prompting the user).
    /// - Its action is `.allow` but it would auto-approve a potentially dangerous command pattern.
    ///
    /// Destructive rules require explicit user confirmation before being saved.
    var isDestructive: Bool {
        // Deny rules are inherently destructive — they silently block tool-use operations
        if action == .deny {
            return true
        }

        let dangerousCommandPatterns = [
            "rm -rf",
            "git push --force",
            "git push -f",
            "DROP ",
            "TRUNCATE ",
            "> /dev/",
            "mkfs",
            "dd if=",
            ":(){"
        ]

        if let prefix = commandPrefix {
            for pattern in dangerousCommandPatterns {
                if prefix.localizedCaseInsensitiveContains(pattern) {
                    return true
                }
            }
        }

        if let glob = pathGlob {
            for pattern in dangerousCommandPatterns {
                if glob.localizedCaseInsensitiveContains(pattern) {
                    return true
                }
            }
        }

        return false
    }

    // MARK: - Matching

    /// Returns true if this rule matches the given tool invocation.
    ///
    /// Matching logic:
    /// - If `toolName` is set, the provided toolName must match (case-insensitive).
    /// - If `commandPrefix` is set, toolInput must start with it (case-insensitive).
    /// - If `pathGlob` is set, toolInput must contain a path that satisfies the glob
    ///   (currently implemented as prefix/suffix matching for common patterns like `/src/**`).
    func matches(toolName: String, toolInput: String) -> Bool {
        guard isEnabled else { return false }

        // Tool name must match if specified
        if let requiredTool = self.toolName {
            guard requiredTool.caseInsensitiveCompare(toolName) == .orderedSame else {
                return false
            }
        }

        // Command prefix must match if specified
        if let prefix = commandPrefix {
            guard toolInput.lowercased().hasPrefix(prefix.lowercased()) else {
                return false
            }
        }

        // Path glob must match if specified
        if let glob = pathGlob {
            guard pathMatches(input: toolInput, glob: glob) else {
                return false
            }
        }

        return true
    }

    // MARK: - Private Helpers

    /// Simple glob matching: supports `*` (any within segment) and `**` (any across segments).
    private func pathMatches(input: String, glob: String) -> Bool {
        // Normalise the glob into prefix / suffix components by splitting on `**`
        let parts = glob.components(separatedBy: "**")

        if parts.count == 1 {
            // No `**` — treat single `*` as any character within the string
            let pattern = glob.replacingOccurrences(of: "*", with: "")
            return input.contains(pattern)
        }

        // With `**` we require input to contain the prefix, then the suffix
        let prefix = parts.first ?? ""
        let suffix = parts.last ?? ""

        let prefixOk = prefix.isEmpty || input.contains(prefix)
        let suffixOk = suffix.isEmpty || input.contains(suffix)
        return prefixOk && suffixOk
    }
}
