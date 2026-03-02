import Foundation
import Vapor
import ILSShared

// MARK: - Interaction Store

/// Actor that tracks user click interactions with suggestions for boosting relevance.
actor SuggestionInteractionStore {
    /// Click counts keyed by suggestion target ID (session ID or skill name).
    var clickCounts: [String: Int] = [:]

    /// Set of dismissed suggestion target IDs (session IDs or skill names).
    private var dismissedIds: Set<String> = []

    /// Record a click interaction for a given target.
    /// - Parameter targetId: The session ID or skill identifier that was clicked.
    func recordClick(targetId: String) {
        clickCounts[targetId.lowercased(), default: 0] += 1
    }

    /// Retrieve the current click counts snapshot.
    /// - Returns: Dictionary of targetId -> click count
    func getCounts() -> [String: Int] {
        clickCounts
    }

    /// Record a dismissal for a given suggestion target.
    /// - Parameter targetId: The session ID or skill identifier that was dismissed.
    func recordDismissal(targetId: String) {
        dismissedIds.insert(targetId.lowercased())
    }

    /// Check whether a suggestion target has been dismissed by the user.
    /// - Parameter targetId: The session ID or skill identifier to query.
    /// - Returns: `true` if the target has been dismissed, `false` otherwise.
    func isDismissed(targetId: String) -> Bool {
        dismissedIds.contains(targetId.lowercased())
    }
}

// MARK: - Suggestion Service

/// Service that scores and ranks sessions and skills based on keyword relevance,
/// recency, and user interaction history.
struct SuggestionService {

    // MARK: - Stopwords

    /// Common English stopwords to exclude from keyword tokenization.
    private static let stopwords: Set<String> = [
        "the", "and", "for", "are", "but", "not", "you", "all", "can",
        "her", "was", "one", "our", "out", "day", "get", "has", "him",
        "his", "how", "its", "new", "now", "old", "see", "two", "who",
        "did", "she", "use", "way", "may", "had", "let", "put", "say",
        "too", "any", "from", "this", "that", "with", "have", "will",
        "your", "what", "been", "when", "into", "some", "than", "then",
        "them", "well", "also", "just", "like", "more", "only", "over",
        "such", "take", "time", "even", "most", "give", "very", "after",
        "said", "each", "does", "made", "about", "which", "there", "their",
        "could", "these", "would", "other", "being", "those", "while"
    ]

    // MARK: - Tokenization

    /// Tokenize a text string into a set of meaningful keywords.
    ///
    /// Strategy: lowercase → split on non-alphanumeric → filter stopwords → min length 3.
    /// - Parameter text: Input text to tokenize.
    /// - Returns: Set of unique keyword tokens.
    func tokenize(_ text: String) -> Set<String> {
        let lowercased = text.lowercased()
        // Split on any sequence of non-alphanumeric characters
        let tokens = lowercased.components(separatedBy: .init(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789").inverted)
        var result = Set<String>()
        for token in tokens {
            // Minimum length of 3, not a stopword
            guard token.count >= 3, !Self.stopwords.contains(token) else { continue }
            result.insert(token)
        }
        return result
    }

    // MARK: - Similarity

    /// Compute Jaccard similarity between two token sets.
    ///
    /// Returns |intersection| / |union|, or 0.0 if both sets are empty.
    /// - Parameters:
    ///   - a: First token set.
    ///   - b: Second token set.
    /// - Returns: Similarity score in [0.0, 1.0].
    func jaccardSimilarity(_ a: Set<String>, _ b: Set<String>) -> Double {
        let unionCount = a.union(b).count
        guard unionCount > 0 else { return 0.0 }
        let intersectionCount = a.intersection(b).count
        return Double(intersectionCount) / Double(unionCount)
    }

    // MARK: - Session Suggestions

    /// Score and rank sessions by relevance to the given context.
    ///
    /// Scoring formula: `0.6 * keyword_overlap + 0.2 * recency_boost + 0.2 * click_boost`
    ///
    /// - Parameters:
    ///   - sessions: All available sessions to score.
    ///   - context: Free-text context (current session name, prompt, etc.).
    ///   - projectName: Optional project name to boost same-project sessions.
    ///   - limit: Maximum number of suggestions to return.
    ///   - clickCounts: User interaction history keyed by session UUID string.
    /// - Returns: Ranked array of `SessionSuggestion` with score > 0.05.
    func suggestSessions(
        from sessions: [ChatSession],
        context: String,
        projectName: String?,
        limit: Int,
        clickCounts: [String: Int]
    ) -> [SessionSuggestion] {
        let contextTokens = tokenize(context)
        let projectTokens = projectName.map { tokenize($0) } ?? Set<String>()
        let now = Date()

        // Max click count for normalisation (avoid division by zero)
        let maxClicks = max(1, clickCounts.values.max() ?? 1)

        var scored: [(session: ChatSession, score: Double)] = []
        scored.reserveCapacity(sessions.count)

        for session in sessions {
            // Build a combined token set from session name, firstPrompt, and project name
            let sessionText = [session.name, session.firstPrompt, session.projectName]
                .compactMap { $0 }
                .joined(separator: " ")
            let sessionTokens = tokenize(sessionText)

            // Keyword overlap — primary signal
            var keywordScore = 0.0
            if !contextTokens.isEmpty || !projectTokens.isEmpty {
                let allContextTokens = contextTokens.union(projectTokens)
                keywordScore = jaccardSimilarity(allContextTokens, sessionTokens)
            }

            // Recency boost — exponential decay over 30 days
            let daysSince = now.timeIntervalSince(session.lastActiveAt) / 86_400
            let recencyBoost = exp(-daysSince / 30.0)  // 1.0 now, ~0.37 at 30 days

            // Click boost — normalised click count
            let clicks = clickCounts[session.id.uuidString.lowercased()] ?? 0
            let clickBoost = Double(clicks) / Double(maxClicks)

            let finalScore = 0.6 * keywordScore + 0.2 * recencyBoost + 0.2 * clickBoost

            scored.append((session: session, score: finalScore))
        }

        // Sort descending by score, filter low-relevance results
        let filtered = scored
            .filter { $0.score > 0.05 }
            .sorted { $0.score > $1.score }
            .prefix(limit)

        return filtered.map { item in
            let reason = buildSessionReason(
                session: item.session,
                contextTokens: contextTokens,
                sessionTokens: tokenize(
                    [item.session.name, item.session.firstPrompt, item.session.projectName]
                        .compactMap { $0 }
                        .joined(separator: " ")
                ),
                score: item.score
            )
            return SessionSuggestion(
                session: item.session,
                score: item.score,
                reason: reason
            )
        }
    }

    /// Build a human-readable reason for a session suggestion.
    private func buildSessionReason(
        session: ChatSession,
        contextTokens: Set<String>,
        sessionTokens: Set<String>,
        score: Double
    ) -> String {
        let shared = contextTokens.intersection(sessionTokens)
        if !shared.isEmpty {
            let keywords = shared.sorted().prefix(3).joined(separator: ", ")
            return "Shares keywords: \(keywords)"
        }
        if let projectName = session.projectName {
            return "From project \(projectName)"
        }
        return "Recently active session"
    }

    // MARK: - Skill Suggestions

    /// Score and rank skills by relevance to the given project and context.
    ///
    /// Scoring: tag match against project/context tokens + description keyword overlap.
    ///
    /// - Parameters:
    ///   - skills: All available skills to score.
    ///   - projectName: Optional project name for tag-based matching.
    ///   - context: Free-text context to score against skill descriptions.
    ///   - limit: Maximum number of suggestions to return.
    /// - Returns: Ranked array of `SkillSuggestion` with score > 0.05.
    func suggestSkills(
        from skills: [Skill],
        projectName: String?,
        context: String,
        limit: Int
    ) -> [SkillSuggestion] {
        let contextTokens = tokenize(context)
        let projectTokens = projectName.map { tokenize($0) } ?? Set<String>()
        let allInputTokens = contextTokens.union(projectTokens)

        var scored: [(skill: Skill, score: Double)] = []
        scored.reserveCapacity(skills.count)

        for skill in skills {
            // Tag match score: fraction of skill tags that overlap with input tokens
            let tagScore: Double
            if skill.tags.isEmpty || allInputTokens.isEmpty {
                tagScore = 0.0
            } else {
                let tagTokens = Set(skill.tags.flatMap { tokenize($0) })
                let matched = tagTokens.intersection(allInputTokens).count
                tagScore = Double(matched) / Double(max(tagTokens.count, 1))
            }

            // Description overlap score
            let descriptionText = [skill.name, skill.description]
                .compactMap { $0 }
                .joined(separator: " ")
            let descTokens = tokenize(descriptionText)
            let descScore = allInputTokens.isEmpty ? 0.0 : jaccardSimilarity(allInputTokens, descTokens)

            // Combined: tags are higher signal than description
            let finalScore = 0.6 * tagScore + 0.4 * descScore

            scored.append((skill: skill, score: finalScore))
        }

        let filtered = scored
            .filter { $0.score > 0.05 }
            .sorted { $0.score > $1.score }
            .prefix(limit)

        return filtered.map { item in
            let reason = buildSkillReason(skill: item.skill, inputTokens: allInputTokens)
            return SkillSuggestion(
                skill: item.skill,
                score: item.score,
                reason: reason
            )
        }
    }

    /// Build a human-readable reason for a skill suggestion.
    private func buildSkillReason(skill: Skill, inputTokens: Set<String>) -> String {
        // Find matching tags
        let matchingTags = skill.tags.filter { tag in
            let tagTokens = tokenize(tag)
            return !tagTokens.intersection(inputTokens).isEmpty
        }
        if !matchingTags.isEmpty {
            let tagList = matchingTags.prefix(3).joined(separator: ", ")
            return "Matches tags: \(tagList)"
        }
        if let description = skill.description, !description.isEmpty {
            return String(description.prefix(60))
        }
        return "Relevant skill for your project"
    }

    // MARK: - Abandoned Session Suggestions

    /// Identify sessions that were abandoned and are worth resuming.
    ///
    /// A session qualifies when:
    /// - It has not been active for more than 24 hours
    /// - It has at least 3 messages (meaningful prior engagement)
    /// - Its status is not `.active`
    /// - Its ID has not been dismissed by the user
    ///
    /// Results are ordered by inactivity duration descending (most neglected first).
    ///
    /// - Parameters:
    ///   - sessions: All available sessions to evaluate.
    ///   - limit: Maximum number of suggestions to return.
    ///   - dismissedIds: Set of lowercased session ID strings to exclude from results.
    /// - Returns: Array of `AbandonedSessionSuggestion` capped at `limit`.
    func suggestAbandoned(
        from sessions: [ChatSession],
        limit: Int,
        dismissedIds: Set<String>
    ) -> [AbandonedSessionSuggestion] {
        let now = Date()
        let abandonedThreshold: TimeInterval = 24 * 3_600  // 24 hours in seconds

        var candidates: [(session: ChatSession, inactivity: TimeInterval)] = []
        candidates.reserveCapacity(sessions.count)

        for session in sessions {
            // Must not be currently active
            guard session.status != .active else { continue }

            // Must have meaningful prior engagement
            guard session.messageCount >= 3 else { continue }

            // Must have been inactive for at least 24 hours
            let inactivity = now.timeIntervalSince(session.lastActiveAt)
            guard inactivity > abandonedThreshold else { continue }

            // Must not have been dismissed by the user
            guard !dismissedIds.contains(session.id.uuidString.lowercased()) else { continue }

            candidates.append((session: session, inactivity: inactivity))
        }

        // Sort by inactivity descending (most abandoned first), then cap to limit
        let sorted = candidates.sorted { $0.inactivity > $1.inactivity }.prefix(limit)

        return sorted.map { item in
            let hoursAgo = Int(item.inactivity / 3_600)
            let reason: String
            if hoursAgo < 48 {
                reason = "Inactive for \(hoursAgo) hours — pick up where you left off"
            } else {
                let daysAgo = hoursAgo / 24
                reason = "Inactive for \(daysAgo) days — worth resuming"
            }

            // Estimate how far along the session was; caps at 95% (never "complete")
            let completionEstimate = min(Int(Double(item.session.messageCount) / 20.0 * 100), 95)

            return AbandonedSessionSuggestion(
                session: item.session,
                inactivityDuration: item.inactivity,
                reason: reason,
                completionEstimate: completionEstimate
            )
        }
    }
}
