import Foundation
import NaturalLanguage
import ILSShared

/// On-device natural language parser that converts a free-text search query
/// into a structured ``ParsedQuery`` for use with ``SessionFilter``.
///
/// Pattern matching runs entirely on-device using ``NLTokenizer`` for tokenisation
/// and a rule-based system for temporal, status, model, project, and topic predicates.
/// Confidence is derived from the ratio of matched tokens to total tokens:
/// any structured predicate pushes the base confidence to 0.5, and each additional
/// matched token increases it toward 1.0.  Pure full-text queries receive 0.3.
final class NLSessionQueryParser: Sendable {

    /// Shared singleton for app-wide use.
    static let shared = NLSessionQueryParser()

    private init() {}

    // MARK: - Public API

    /// Parses a natural-language query into a structured ``ParsedQuery``.
    ///
    /// - Parameters:
    ///   - query: The raw string typed by the user.
    ///   - knownProjects: Project names visible in the current context, used for
    ///     fuzzy project-name matching against "in \<name\>" phrases.
    /// - Returns: A ``ParsedQuery`` with extracted predicates and a human-readable
    ///   explanation string.
    func parse(_ query: String, knownProjects: [String] = []) -> ParsedQuery {
        let trimmed  = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered  = trimmed.lowercased()

        guard !lowered.isEmpty else {
            return ParsedQuery(
                originalQuery: query,
                searchTokens: [],
                dateRange: nil,
                modelFilter: nil,
                statusFilter: nil,
                projectFilter: nil,
                confidence: 0.0,
                explanation: ""
            )
        }

        // Tokenise into individual words using NLTokenizer.
        var tokens    = wordTokens(from: lowered)
        let totalCount = tokens.count

        // Each extractor pattern-matches the full lowered string and removes
        // consumed tokens from `tokens` in-place so unmatched words remain.
        let dateRange     = extractDateRange(from: lowered, tokens: &tokens)
        let statusFilter  = extractStatus(from: lowered, tokens: &tokens)
        let modelFilter   = extractModel(from: lowered, tokens: &tokens)
        let projectFilter = extractProject(from: lowered, tokens: &tokens, knownProjects: knownProjects)

        // Remaining tokens (after stop-word stripping) become free-text search terms.
        let searchTokens = topicTokens(from: tokens)

        // Confidence: starts at 0.5 if any structured predicate was found, scaling
        // up proportionally to matched tokens; 0.3 for plain text-only queries.
        let matchedCount  = totalCount - tokens.count
        let hasStructured = dateRange != nil || statusFilter != nil
                         || modelFilter != nil || projectFilter != nil

        let confidence: Double
        if totalCount == 0 {
            confidence = 0.0
        } else if hasStructured {
            let ratio = Double(matchedCount) / Double(totalCount)
            confidence = min(0.5 + ratio * 0.5, 1.0)
        } else {
            confidence = searchTokens.isEmpty ? 0.0 : 0.3
        }

        // Assemble the result and then build the explanation from it.
        var result = ParsedQuery(
            originalQuery: query,
            searchTokens: searchTokens,
            dateRange: dateRange,
            modelFilter: modelFilter,
            statusFilter: statusFilter,
            projectFilter: projectFilter,
            confidence: confidence,
            explanation: ""
        )
        result.explanation = buildExplanation(from: result)
        return result
    }

    // MARK: - Tokenisation

    private func wordTokens(from text: String) -> [String] {
        var words: [String] = []
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let word = String(text[range])
            if !word.isEmpty { words.append(word) }
            return true
        }
        return words
    }

    // MARK: - Date Range Extraction

    /// Extracts a temporal predicate such as "today", "last week", or "last 7 days".
    private func extractDateRange(from text: String, tokens: inout [String]) -> FilterDateRange? {
        // Multi-word phrases checked before single-word to avoid partial matches.
        let phrases: [(pattern: String, range: FilterDateRange, words: [String])] = [
            ("\\blast\\s+week\\b",  .lastWeek,  ["last", "week"]),
            ("\\bthis\\s+week\\b",  .thisWeek,  ["this", "week"]),
            ("\\blast\\s+month\\b", .lastMonth, ["last", "month"]),
            ("\\bthis\\s+month\\b", .thisMonth, ["this", "month"]),
            ("\\byesterday\\b",     .yesterday, ["yesterday"]),
            ("\\btoday\\b",         .today,     ["today"]),
        ]

        for phrase in phrases {
            if regexMatches(phrase.pattern, in: text) {
                consume(phrase.words, from: &tokens)
                return phrase.range
            }
        }

        return extractRelativePeriod(from: text, tokens: &tokens)
    }

    /// Handles "last N days", "past N weeks", etc., returning a `.custom` range.
    private func extractRelativePeriod(from text: String, tokens: inout [String]) -> FilterDateRange? {
        let pattern = "\\b(last|past)\\s+(\\d+)\\s+(day|days|week|weeks)\\b"
        guard let regex   = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match   = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let kwRange = Range(match.range(at: 1), in: text),
              let numRange = Range(match.range(at: 2), in: text),
              let unitRange = Range(match.range(at: 3), in: text),
              let n = Int(text[numRange]) else { return nil }

        let keyword = String(text[kwRange])
        let unit    = String(text[unitRange])
        let now     = Date()
        let calendar = Calendar.current

        let start: Date?
        if unit.hasPrefix("week") {
            start = calendar.date(byAdding: .weekOfYear, value: -n, to: now)
        } else {
            start = calendar.date(byAdding: .day, value: -n, to: now)
        }

        guard let startDate = start else { return nil }
        consume([keyword, String(n), unit], from: &tokens)
        return .custom(startDate, now)
    }

    // MARK: - Status Extraction

    /// Extracts a ``SessionStatus`` predicate from phrases such as "with errors",
    /// "active", "completed", or "cancelled".
    private func extractStatus(from text: String, tokens: inout [String]) -> SessionStatus? {
        let patterns: [(pattern: String, status: SessionStatus, words: [String])] = [
            ("\\bwith\\s+errors?\\b",     .error,     ["with", "error", "errors"]),
            ("\\berror\\s+sessions?\\b",  .error,     ["error", "session", "sessions"]),
            ("\\berrored\\b",             .error,     ["errored"]),
            ("\\bfailed\\b",              .error,     ["failed"]),
            ("\\bactive\\b",              .active,    ["active"]),
            ("\\bcompleted\\b",           .completed, ["completed"]),
            ("\\bdone\\b",                .completed, ["done"]),
            ("\\bfinished\\b",            .completed, ["finished"]),
            ("\\bcancell?ed\\b",          .cancelled, ["cancelled", "canceled"]),
            ("\\bstopped\\b",             .cancelled, ["stopped"]),
        ]

        for item in patterns {
            if regexMatches(item.pattern, in: text) {
                consume(item.words, from: &tokens)
                return item.status
            }
        }
        return nil
    }

    // MARK: - Model Extraction

    /// Extracts a model family keyword: "sonnet", "haiku", or "opus".
    private func extractModel(from text: String, tokens: inout [String]) -> String? {
        for model in ["sonnet", "haiku", "opus"] {
            if regexMatches("\\b\(model)\\b", in: text) {
                consume([model], from: &tokens)
                return model
            }
        }
        return nil
    }

    // MARK: - Project Extraction

    /// Extracts a project name from phrases like "for project X", "in X project",
    /// "from X project", or "project X".  Falls back to fuzzy matching against
    /// `knownProjects` for "in \<name\>" patterns.
    private func extractProject(
        from text: String,
        tokens: inout [String],
        knownProjects: [String]
    ) -> String? {
        // "for project <name>" or "project <name>"
        if let name = firstCapture(
            pattern: "\\b(?:for\\s+)?project\\s+([\\w-]+)",
            in: text
        ) {
            consume(["for", "project", name], from: &tokens)
            return name
        }

        // "in <name> project" or "from <name> project"
        if let name = firstCapture(
            pattern: "\\b(?:in|from)\\s+([\\w-]+)\\s+project\\b",
            in: text
        ) {
            consume(["in", "from", name, "project"], from: &tokens)
            return name
        }

        // "in <knownProject>" — fuzzy match against the supplied project list.
        let loweredKnown = knownProjects.map { $0.lowercased() }
        if !loweredKnown.isEmpty,
           let candidate = firstCapture(
               pattern: "\\bin\\s+([\\w-]+(?:\\s+[\\w-]+){0,2})\\b",
               in: text
           ) {
            let isKnown = loweredKnown.contains {
                $0 == candidate || $0.hasPrefix(candidate) || candidate.hasPrefix($0)
            }
            if isKnown {
                consume(["in"] + candidate.components(separatedBy: " "), from: &tokens)
                return candidate
            }
        }

        return nil
    }

    // MARK: - Topic Token Extraction

    private static let stopWords: Set<String> = [
        "a", "an", "the", "and", "or", "not", "for", "in", "on", "at", "to", "from",
        "with", "of", "is", "are", "was", "were", "be", "been", "being",
        "session", "sessions", "about", "show", "find", "search", "get",
        "me", "my", "i", "all", "any", "using", "use",
    ]

    /// Returns meaningful content tokens from the remaining (unmatched) word list,
    /// stripping structural stop words and the "about" discourse marker.
    private func topicTokens(from tokens: [String]) -> [String] {
        tokens.filter { !Self.stopWords.contains($0) }
    }

    // MARK: - Explanation Builder

    private func buildExplanation(from query: ParsedQuery) -> String {
        var parts: [String] = []

        if let project = query.projectFilter {
            parts.append("project=\(project)")
        }
        if let range = query.dateRange {
            parts.append("date=\(range.displayName)")
        }
        if let status = query.statusFilter {
            parts.append("status=\(status.rawValue)")
        }
        if let model = query.modelFilter {
            parts.append("model=\(model)")
        }
        if !query.searchTokens.isEmpty {
            parts.append("topic=\(query.searchTokens.joined(separator: " "))")
        }

        guard !parts.isEmpty else { return "" }
        return "Showing: " + parts.joined(separator: " · ")
    }

    // MARK: - Regex Helpers

    /// Returns `true` when *pattern* (case-insensitive) finds a match anywhere in *text*.
    private func regexMatches(_ pattern: String, in text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return false
        }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    /// Returns the first capture group string when *pattern* matches *text*, or `nil`.
    private func firstCapture(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[captureRange])
    }

    /// Removes the first occurrence of each word in *words* from *tokens*.
    private func consume(_ words: [String], from tokens: inout [String]) {
        for word in words {
            if let idx = tokens.firstIndex(of: word) {
                tokens.remove(at: idx)
            }
        }
    }
}
