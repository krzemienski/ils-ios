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

    /// Retrieve the current set of dismissed suggestion target IDs.
    /// - Returns: Set of lowercased target ID strings.
    func getDismissedIds() -> Set<String> {
        dismissedIds
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
    /// Scoring formula:
    /// `0.5 * keyword_overlap + 0.15 * recency_boost + 0.15 * click_boost + 0.1 * git_branch_boost + 0.1 * time_of_day_boost`
    ///
    /// - Parameters:
    ///   - sessions: All available sessions to score.
    ///   - context: Free-text context (current session name, prompt, etc.).
    ///   - projectName: Optional project name to boost same-project sessions.
    ///   - gitBranch: Optional current git branch name; sessions whose content matches
    ///     branch tokens receive a 0.1 weight boost.
    ///   - limit: Maximum number of suggestions to return.
    ///   - clickCounts: User interaction history keyed by session UUID string.
    /// - Returns: Ranked array of `SessionSuggestion` with score > 0.05.
    func suggestSessions(
        from sessions: [ChatSession],
        context: String,
        projectName: String?,
        gitBranch: String? = nil,
        limit: Int,
        clickCounts: [String: Int]
    ) -> [SessionSuggestion] {
        let contextTokens = tokenize(context)
        let projectTokens = projectName.map { tokenize($0) } ?? Set<String>()
        let gitBranchTokens = gitBranch.map { tokenize($0) } ?? Set<String>()
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

            // Git branch boost — 1.0 if any branch token appears in session tokens, else 0.0
            let gitBranchBoost: Double
            if !gitBranchTokens.isEmpty && !sessionTokens.isEmpty {
                gitBranchBoost = gitBranchTokens.intersection(sessionTokens).isEmpty ? 0.0 : 1.0
            } else {
                gitBranchBoost = 0.0
            }

            // Time-of-day boost — sessions last active at a similar hour get a boost
            let timeOfDayBoost = computeTimeOfDayBoost(sessionLastActive: session.lastActiveAt, now: now)

            let finalScore = 0.5 * keywordScore
                + 0.15 * recencyBoost
                + 0.15 * clickBoost
                + 0.1 * gitBranchBoost
                + 0.1 * timeOfDayBoost

            scored.append((session: session, score: finalScore))
        }

        // Sort descending by score, filter low-relevance results
        let filtered = scored
            .filter { $0.score > 0.05 }
            .sorted { $0.score > $1.score }
            .prefix(limit)

        return filtered.map { item in
            let sessionText = [item.session.name, item.session.firstPrompt, item.session.projectName]
                .compactMap { $0 }
                .joined(separator: " ")
            let reason = buildSessionReason(
                session: item.session,
                contextTokens: contextTokens,
                sessionTokens: tokenize(sessionText),
                gitBranchTokens: gitBranchTokens,
                score: item.score
            )
            return SessionSuggestion(
                session: item.session,
                score: item.score,
                reason: reason
            )
        }
    }

    /// Compute a boost for sessions that were last active at a similar time of day.
    ///
    /// Uses circular hour distance with exponential decay over a 4-hour window.
    /// Peaks at 1.0 when the session's last-active hour matches the current hour exactly,
    /// and decays to ~0.37 at a 4-hour difference.
    ///
    /// - Parameters:
    ///   - sessionLastActive: When the session was last active.
    ///   - now: Current timestamp.
    /// - Returns: Boost value in [0.0, 1.0].
    private func computeTimeOfDayBoost(sessionLastActive: Date, now: Date) -> Double {
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let sessionHour = calendar.component(.hour, from: sessionLastActive)
        let rawDiff = abs(currentHour - sessionHour)
        let circularDiff = min(rawDiff, 24 - rawDiff)
        return exp(-Double(circularDiff) / 4.0)
    }

    /// Build a human-readable reason for a session suggestion.
    private func buildSessionReason(
        session: ChatSession,
        contextTokens: Set<String>,
        sessionTokens: Set<String>,
        gitBranchTokens: Set<String>,
        score: Double
    ) -> String {
        // Git branch match is the most specific signal — check first
        if !gitBranchTokens.isEmpty && !gitBranchTokens.intersection(sessionTokens).isEmpty {
            return "Active on current branch"
        }
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

    // MARK: - Smart Continuation

    /// Generate a smart continuation summary for a session based on its recent messages.
    ///
    /// Algorithm:
    /// 1. Extract the last 5 user messages.
    /// 2. Tokenize their combined content, counting token frequencies.
    /// 3. Select the top 5 tokens as key topics.
    /// 4. Compose a summary and a ready-to-use resume prompt.
    ///
    /// - Parameters:
    ///   - session: The session to summarize.
    ///   - messages: All messages in the session (any order; method finds the most recent).
    /// - Returns: A `ContinuationSummary` ready to present to the user as a resume prompt.
    func buildContinuationSummary(session: ChatSession, messages: [Message]) -> ContinuationSummary {
        // Extract the last 5 user messages in chronological order
        let userMessages = messages
            .filter { $0.role == .user }
            .sorted { $0.createdAt < $1.createdAt }
            .suffix(5)

        // Count token frequencies across all extracted user messages
        var tokenFrequencies: [String: Int] = [:]
        for message in userMessages {
            let tokens = tokenize(message.content)
            for token in tokens {
                tokenFrequencies[token, default: 0] += 1
            }
        }

        // Top 5 tokens by frequency as key topics
        let keyTopics = tokenFrequencies
            .sorted { $0.value > $1.value || ($0.value == $1.value && $0.key < $1.key) }
            .prefix(5)
            .map { $0.key }

        // Build a human-readable summary
        let sessionName = session.name ?? "this session"
        let summary: String
        if keyTopics.isEmpty {
            summary = "You were working in \"\(sessionName)\" with \(messages.count) messages."
        } else {
            let topicsPhrase = keyTopics.joined(separator: ", ")
            summary = "You were working in \"\(sessionName)\" on topics: \(topicsPhrase)."
        }

        // Generate a suggested resume prompt
        let suggestedPrompt: String
        if keyTopics.isEmpty {
            suggestedPrompt = "Let's continue where we left off in \"\(sessionName)\"."
        } else {
            let firstTopic = keyTopics[0]
            suggestedPrompt = "Let's continue where we left off. Last time we were discussing \(firstTopic) — please summarize the current state and suggest next steps."
        }

        return ContinuationSummary(
            sessionId: session.id,
            summary: summary,
            suggestedPrompt: suggestedPrompt,
            keyTopics: keyTopics,
            messageCount: userMessages.count
        )
    }
}
