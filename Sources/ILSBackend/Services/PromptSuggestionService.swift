import Foundation
import Vapor
import ILSShared

// MARK: - Prompt Template

/// Represents a contextual prompt template with trigger keywords and category.
struct PromptTemplate {
    /// The suggested prompt text.
    let text: String
    /// Keywords that make this prompt relevant.
    let keywords: Set<String>
    /// Category for grouping and prioritization.
    let category: String
    /// Base relevance score (0.0 - 1.0).
    let baseScore: Double
    /// Reason template for user-facing explanation.
    let reasonTemplate: String

    init(text: String, keywords: Set<String>, category: String, baseScore: Double = 0.5, reasonTemplate: String) {
        self.text = text
        self.keywords = keywords
        self.category = category
        self.baseScore = baseScore
        self.reasonTemplate = reasonTemplate
    }
}

// MARK: - Prompt Suggestion Service

/// Service that generates context-aware prompt suggestions based on conversation flow and common developer patterns.
///
/// Analyzes conversation context to recommend relevant follow-up prompts like:
/// - "Add unit tests for this code"
/// - "Explain how this works"
/// - "Fix the error"
/// - "Optimize performance"
struct PromptSuggestionService {

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

    // MARK: - Prompt Templates

    /// Predefined prompt templates organized by common developer workflows.
    private static let templates: [PromptTemplate] = [
        // Testing prompts
        PromptTemplate(
            text: "Add unit tests for this code",
            keywords: ["function", "method", "class", "code", "implement", "create", "build"],
            category: "testing",
            baseScore: 0.7,
            reasonTemplate: "Code implementation detected"
        ),
        PromptTemplate(
            text: "Add integration tests",
            keywords: ["api", "endpoint", "service", "database", "integration"],
            category: "testing",
            baseScore: 0.65,
            reasonTemplate: "API or service code detected"
        ),
        PromptTemplate(
            text: "Add edge case tests",
            keywords: ["test", "testing", "coverage", "edge", "case"],
            category: "testing",
            baseScore: 0.6,
            reasonTemplate: "Test coverage discussion"
        ),

        // Error handling prompts
        PromptTemplate(
            text: "Fix the error",
            keywords: ["error", "exception", "fail", "crash", "bug", "issue", "problem"],
            category: "debugging",
            baseScore: 0.8,
            reasonTemplate: "Error or issue mentioned"
        ),
        PromptTemplate(
            text: "Debug this issue",
            keywords: ["debug", "trace", "investigate", "diagnose", "troubleshoot"],
            category: "debugging",
            baseScore: 0.75,
            reasonTemplate: "Debugging request"
        ),
        PromptTemplate(
            text: "Add error handling",
            keywords: ["validate", "check", "handle", "catch", "throw"],
            category: "debugging",
            baseScore: 0.65,
            reasonTemplate: "Error handling context"
        ),

        // Code explanation prompts
        PromptTemplate(
            text: "Explain how this works",
            keywords: ["complex", "algorithm", "logic", "function", "implementation"],
            category: "explanation",
            baseScore: 0.6,
            reasonTemplate: "Complex code implementation"
        ),
        PromptTemplate(
            text: "Add code comments",
            keywords: ["comment", "document", "explain", "clarify", "describe"],
            category: "explanation",
            baseScore: 0.55,
            reasonTemplate: "Documentation needed"
        ),
        PromptTemplate(
            text: "Simplify this code",
            keywords: ["complex", "complicated", "refactor", "simplify", "clean"],
            category: "explanation",
            baseScore: 0.6,
            reasonTemplate: "Code complexity detected"
        ),

        // Performance prompts
        PromptTemplate(
            text: "Optimize performance",
            keywords: ["slow", "performance", "optimize", "speed", "efficient", "fast"],
            category: "performance",
            baseScore: 0.7,
            reasonTemplate: "Performance concern"
        ),
        PromptTemplate(
            text: "Reduce memory usage",
            keywords: ["memory", "leak", "allocation", "cache", "storage"],
            category: "performance",
            baseScore: 0.65,
            reasonTemplate: "Memory-related code"
        ),

        // Refactoring prompts
        PromptTemplate(
            text: "Refactor to follow best practices",
            keywords: ["refactor", "improve", "clean", "pattern", "architecture"],
            category: "refactoring",
            baseScore: 0.6,
            reasonTemplate: "Code improvement context"
        ),
        PromptTemplate(
            text: "Extract this into a separate function",
            keywords: ["duplicate", "repeat", "reuse", "extract", "separate"],
            category: "refactoring",
            baseScore: 0.55,
            reasonTemplate: "Code organization opportunity"
        ),

        // Documentation prompts
        PromptTemplate(
            text: "Add documentation",
            keywords: ["document", "readme", "guide", "tutorial", "api"],
            category: "documentation",
            baseScore: 0.5,
            reasonTemplate: "Documentation context"
        ),

        // Security prompts
        PromptTemplate(
            text: "Check for security issues",
            keywords: ["security", "auth", "authentication", "authorization", "vulnerability", "sanitize"],
            category: "security",
            baseScore: 0.75,
            reasonTemplate: "Security-related code"
        ),

        // Generic helpful prompts
        PromptTemplate(
            text: "Show me an example",
            keywords: ["example", "sample", "demo", "usage", "how"],
            category: "generic",
            baseScore: 0.4,
            reasonTemplate: "Common follow-up"
        ),
        PromptTemplate(
            text: "What are the alternatives?",
            keywords: ["alternative", "option", "different", "approach", "solution"],
            category: "generic",
            baseScore: 0.45,
            reasonTemplate: "Exploring options"
        ),
        PromptTemplate(
            text: "Continue with the next step",
            keywords: ["next", "continue", "step", "proceed", "then"],
            category: "generic",
            baseScore: 0.35,
            reasonTemplate: "Sequential workflow"
        )
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

    // MARK: - Prompt Suggestions

    /// Generate ranked prompt suggestions based on conversation and project context.
    ///
    /// Scoring formula: `baseScore * (1.0 + 0.5 * keyword_overlap) + clickBoost`
    ///
    /// - Parameters:
    ///   - conversationContext: Recent conversation messages or topics discussed.
    ///   - projectContext: Project-specific info (language, framework, etc.).
    ///   - clickCounts: Dictionary of prompt text -> click count for relevance boosting.
    ///   - limit: Maximum number of suggestions to return (default 4).
    /// - Returns: Ranked array of `PromptSuggestion` with diverse categories.
    func suggestPrompts(
        conversationContext: String?,
        projectContext: String?,
        clickCounts: [String: Int] = [:],
        limit: Int = 4
    ) -> [PromptSuggestion] {
        // Combine all context
        let allContext = [conversationContext, projectContext]
            .compactMap { $0 }
            .joined(separator: " ")

        guard !allContext.isEmpty else {
            // Return generic suggestions if no context
            return defaultSuggestions(limit: limit)
        }

        let contextTokens = tokenize(allContext)

        var scored: [(template: PromptTemplate, score: Double, matchedKeywords: Set<String>)] = []
        scored.reserveCapacity(Self.templates.count)

        for template in Self.templates {
            // Calculate keyword overlap
            let matchedKeywords = template.keywords.intersection(contextTokens)
            let keywordScore = matchedKeywords.isEmpty ? 0.0 : Double(matchedKeywords.count) / Double(template.keywords.count)

            // Boost score based on user interaction history (capped at 5 clicks = 0.25 boost)
            let clicks = clickCounts[template.text.lowercased(), default: 0]
            let clickBoost = Double(min(clicks, 5)) * 0.05

            // Boost base score by keyword relevance and click history
            let finalScore = template.baseScore * (1.0 + 0.5 * keywordScore) + clickBoost

            scored.append((template: template, score: finalScore, matchedKeywords: matchedKeywords))
        }

        // Sort by score descending
        scored.sort { $0.score > $1.score }

        // Select diverse suggestions from different categories
        var selected: [(template: PromptTemplate, score: Double, matchedKeywords: Set<String>)] = []
        var usedCategories = Set<String>()

        // First pass: take top-scoring suggestions from different categories
        for item in scored {
            if selected.count >= limit {
                break
            }
            if !usedCategories.contains(item.template.category) {
                selected.append(item)
                usedCategories.insert(item.template.category)
            }
        }

        // Second pass: fill remaining slots with highest scoring items regardless of category
        if selected.count < limit {
            for item in scored {
                if selected.count >= limit {
                    break
                }
                if !selected.contains(where: { $0.template.text == item.template.text }) {
                    selected.append(item)
                }
            }
        }

        // Convert to PromptSuggestion DTOs
        return selected.map { item in
            let reason = buildReason(
                template: item.template,
                matchedKeywords: item.matchedKeywords,
                contextTokens: contextTokens
            )
            return PromptSuggestion(
                id: UUID(),
                prompt: item.template.text,
                score: item.score,
                reason: reason
            )
        }
    }

    /// Build a human-readable reason for a prompt suggestion.
    private func buildReason(
        template: PromptTemplate,
        matchedKeywords: Set<String>,
        contextTokens: Set<String>
    ) -> String {
        if !matchedKeywords.isEmpty {
            let keywords = matchedKeywords.sorted().prefix(2).joined(separator: ", ")
            return "\(template.reasonTemplate): \(keywords)"
        }
        return template.reasonTemplate
    }

    /// Return default suggestions when no context is available.
    private func defaultSuggestions(limit: Int) -> [PromptSuggestion] {
        let defaults = [
            ("Explain how this works", "Common follow-up question"),
            ("Add unit tests for this code", "Best practice recommendation"),
            ("Optimize performance", "Improvement suggestion"),
            ("Add documentation", "Code quality improvement")
        ]

        return defaults.prefix(limit).enumerated().map { index, item in
            PromptSuggestion(
                id: UUID(),
                prompt: item.0,
                score: 0.5 - (Double(index) * 0.05),
                reason: item.1
            )
        }
    }
}
