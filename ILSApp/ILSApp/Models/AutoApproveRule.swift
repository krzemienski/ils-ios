import Foundation

// MARK: - AutoApproveRule

/// A user-configured rule for automatically approving permission requests without manual confirmation.
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
    /// Whether this rule is currently active.
    var isEnabled: Bool
    /// The project this rule is scoped to. A nil value means the rule is global.
    var projectId: UUID?
    /// An optional human-readable description of the rule's intent.
    var note: String?
    /// When this rule was created.
    var createdAt: Date

    init(
        id: UUID = UUID(),
        toolName: String? = nil,
        pathGlob: String? = nil,
        commandPrefix: String? = nil,
        isEnabled: Bool = true,
        projectId: UUID? = nil,
        note: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.toolName = toolName
        self.pathGlob = pathGlob
        self.commandPrefix = commandPrefix
        self.isEnabled = isEnabled
        self.projectId = projectId
        self.note = note
        self.createdAt = createdAt
    }

    // MARK: - Destructive Operation Detection

    /// Returns true if this rule would auto-approve a potentially destructive operation.
    /// Rules matching dangerous patterns require explicit user confirmation before being saved.
    var isDestructive: Bool {
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
