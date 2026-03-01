import Foundation

/// Lightweight fuzzy string matching utility for the command palette.
///
/// Returns a relevance score (0.0–1.0) indicating how well a query matches
/// a target string. Used to filter and rank command palette results.
enum FuzzyMatcher {

    // MARK: - Public API

    /// Returns a relevance score for `query` matched against `target`.
    ///
    /// - Parameters:
    ///   - query: The search string typed by the user.
    ///   - target: The string to match against (e.g. a command title).
    /// - Returns: A score in the range `0.0...1.0`. Higher is a better match.
    ///   Returns `1.0` when `query` is empty (everything matches perfectly).
    ///   Returns `0.0` when no sequential character match is found.
    static func score(query: String, in target: String) -> Double {
        guard !query.isEmpty else { return 1.0 }

        let q = query.lowercased()
        let t = target.lowercased()

        // Exact full match
        if t == q { return 1.0 }

        // Substring match — highest non-exact score band
        if let range = t.range(of: q) {
            var base = 0.8
            // Boost when the match starts at the very beginning of the string
            if range.lowerBound == t.startIndex {
                base += 0.15
            } else {
                // Boost when the match starts at a word boundary (preceded by space/dash/etc.)
                let preceding = t[t.startIndex..<range.lowerBound]
                if let last = preceding.last, isBoundary(last) {
                    base += 0.08
                }
            }
            return min(base, 1.0)
        }

        // Sequential character match — characters of query found in order inside target
        return sequentialScore(query: q, target: t)
    }

    /// Returns `true` when the relevance score for `query` against `target`
    /// exceeds the minimum threshold (0.1).
    ///
    /// - Parameters:
    ///   - query: The search string typed by the user.
    ///   - target: The string to match against.
    /// - Returns: `true` if there is a meaningful match.
    static func matches(query: String, in target: String) -> Bool {
        score(query: query, in: target) > 0.1
    }

    // MARK: - Private Helpers

    /// Checks whether `character` is a word-boundary separator.
    private static func isBoundary(_ character: Character) -> Bool {
        character == " " || character == "-" || character == "_" || character == "/"
    }

    /// Computes a score based on sequential (in-order) character matching.
    ///
    /// Iterates through each character of `query`, finding it in order within
    /// `target`. The score reflects both whether all characters were found and
    /// how densely they are clustered (fewer gaps → higher score).
    ///
    /// - Returns: A value in `0.0..<0.8`, or `0.0` if no sequential match exists.
    private static func sequentialScore(query: String, target: String) -> Double {
        let queryChars = Array(query)
        let targetChars = Array(target)

        var queryIndex = 0
        var firstMatchPos = -1
        var lastMatchPos = -1
        var matchCount = 0

        for (targetPos, tChar) in targetChars.enumerated() {
            guard queryIndex < queryChars.count else { break }
            if tChar == queryChars[queryIndex] {
                if firstMatchPos == -1 { firstMatchPos = targetPos }
                lastMatchPos = targetPos
                matchCount += 1
                queryIndex += 1
            }
        }

        // All query characters must be found in order
        guard matchCount == queryChars.count else { return 0.0 }

        // Base sequential score: 0.3–0.7 depending on character coverage
        let coverageFraction = Double(matchCount) / Double(targetChars.count)
        let baseScore = 0.3 + coverageFraction * 0.4

        // Density bonus: reward matches that are tightly clustered
        let span = lastMatchPos - firstMatchPos + 1
        let density = Double(matchCount) / Double(max(span, 1))
        let densityBonus = density * 0.1

        return min(baseScore + densityBonus, 0.79)
    }
}
