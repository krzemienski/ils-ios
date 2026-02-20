import Foundation

// MARK: - Session Title Cleaning

public extension String {
    /// Strips markdown heading prefixes and system prompt markers, then truncates.
    ///
    /// Session names from Claude Code often contain `## YOUR ROLE`, `# Task Summary`,
    /// or `You are a...` system prompts. This normalizes them into clean display titles.
    ///
    /// - Parameter maxLength: Maximum character count before truncation (default 50)
    /// - Returns: Cleaned, truncated string
    func cleanedSessionTitle(maxLength: Int = 50) -> String {
        let cleaned = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return cleaned }

        // Strip markdown headings or "You are" system prompt prefixes
        if cleaned.hasPrefix("#") || cleaned.hasPrefix("You are") {
            let stripped = cleaned.hasPrefix("#")
                ? String(cleaned.drop(while: { $0 == "#" || $0 == " " }))
                : cleaned
            let firstLine = stripped.prefix(while: { $0 != "\n" })
            let result = String(firstLine)
            return result.count > maxLength
                ? String(result.prefix(maxLength)) + "..."
                : result
        }

        // Plain text truncation with small buffer to avoid awkward mid-word cuts
        if cleaned.count > maxLength + 7 {
            return String(cleaned.prefix(maxLength)) + "..."
        }
        return cleaned
    }
}

public extension Optional where Wrapped == String {
    /// Convenience for optional session names. Returns nil if nil or empty.
    func cleanedSessionTitle(maxLength: Int = 50) -> String? {
        guard let self, !self.isEmpty else { return nil }
        return self.cleanedSessionTitle(maxLength: maxLength)
    }
}
