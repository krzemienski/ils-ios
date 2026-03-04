import Foundation
import ILSShared

// MARK: - Model Routing Service

/// Pure-Swift service that applies heuristic rules to select the optimal Claude
/// model for a given prompt and budget.
///
/// No database or filesystem access is performed — the service is stateless and
/// can be instantiated inline in any request handler.
struct ModelRoutingService {

    // MARK: - Complexity Keywords

    /// Keywords that signal a complex, high-stakes task warranting Claude Opus.
    private static let complexityKeywords: Set<String> = [
        "architecture", "refactor", "design", "analyze", "analyse",
        "explain", "complex", "optimize", "optimise", "review",
        "security", "performance", "debug", "implement", "integrate"
    ]

    // MARK: - Model Suggestion

    /// Suggest the most appropriate Claude model for a given prompt and constraints.
    ///
    /// Heuristic order (first match wins):
    /// 1. If `maxBudgetUSD` is non-nil and ≤ 1.0, recommend **Haiku** (budget constraint).
    /// 2. If `preferSpeed` is `true`, recommend **Haiku** (latency preference).
    /// 3. If the prompt is complex (> 500 words or contains complexity keywords),
    ///    recommend **Opus**.
    /// 4. Otherwise recommend **Sonnet** (balanced default).
    ///
    /// - Parameters:
    ///   - prompt: The user's task description or first message.
    ///   - maxBudgetUSD: Maximum acceptable cost in USD, or `nil` for no constraint.
    ///   - preferSpeed: When `true`, prefer lower-latency models.
    /// - Returns: A ``ModelRoutingResponse`` with the suggested model and reasoning.
    func suggestModel(
        prompt: String,
        maxBudgetUSD: Double? = nil,
        preferSpeed: Bool? = nil
    ) -> ModelRoutingResponse {

        // Rule 1: Hard budget constraint — Haiku is cheapest
        if let budget = maxBudgetUSD, budget <= 1.0 {
            return ModelRoutingResponse(
                suggestedModel: ClaudeModel.haiku.rawValue,
                reasoning: "Budget constraint (≤ $1.00) — Haiku provides the lowest cost at $0.80/M input tokens.",
                estimatedCostUSD: nil,
                alternativeModels: [ClaudeModel.sonnet.rawValue]
            )
        }

        // Rule 2: Speed preference — Haiku has lowest latency
        if preferSpeed == true {
            return ModelRoutingResponse(
                suggestedModel: ClaudeModel.haiku.rawValue,
                reasoning: "Speed preference selected — Haiku offers the fastest response times.",
                estimatedCostUSD: nil,
                alternativeModels: [ClaudeModel.sonnet.rawValue, ClaudeModel.opus.rawValue]
            )
        }

        // Rule 3: Complexity analysis — check word count and keywords
        if isComplexPrompt(prompt) {
            let matchedKeywords = extractMatchedKeywords(from: prompt)
            let reason: String
            if prompt.split(separator: " ").count > 500 {
                reason = "Long, detailed prompt suggests a complex task — Opus provides the highest capability."
            } else {
                let keywordList = matchedKeywords.sorted().prefix(3).joined(separator: ", ")
                reason = "Complexity indicators detected (\(keywordList)) — Opus is recommended for complex tasks."
            }
            return ModelRoutingResponse(
                suggestedModel: ClaudeModel.opus.rawValue,
                reasoning: reason,
                estimatedCostUSD: nil,
                alternativeModels: [ClaudeModel.sonnet.rawValue, ClaudeModel.haiku.rawValue]
            )
        }

        // Rule 4: Default — Sonnet balances quality and cost
        return ModelRoutingResponse(
            suggestedModel: ClaudeModel.sonnet.rawValue,
            reasoning: "Balanced task — Sonnet offers strong performance at a moderate cost.",
            estimatedCostUSD: nil,
            alternativeModels: [ClaudeModel.haiku.rawValue, ClaudeModel.opus.rawValue]
        )
    }

    // MARK: - Budget-Aware Downgrade

    /// Downgrade a requested model when the used cost is approaching the budget limit.
    ///
    /// When more than 80 % of the budget has been consumed, the service steps down
    /// to the next cheaper model:
    /// - Opus → Sonnet
    /// - Sonnet → Haiku
    /// - Haiku → Haiku (already cheapest)
    ///
    /// If no budget is set, the requested model is returned unchanged.
    ///
    /// - Parameters:
    ///   - requested: The model originally requested for the session.
    ///   - usedCostUSD: Cumulative cost consumed so far in USD.
    ///   - maxBudgetUSD: The session's budget ceiling in USD, or `nil` for unlimited.
    /// - Returns: The model identifier to use — either the original or a cheaper fallback.
    func budgetAwareModel(
        requested: String,
        usedCostUSD: Double,
        maxBudgetUSD: Double?
    ) -> String {
        guard let budget = maxBudgetUSD, budget > 0 else {
            // No budget constraint — honour the original request
            return requested
        }

        let usedFraction = usedCostUSD / budget

        // Downgrade when ≥ 80 % of the budget is consumed
        guard usedFraction >= 0.8 else {
            return requested
        }

        let model = ClaudeModel(rawValue: requested) ?? .sonnet
        switch model {
        case .opus:
            return ClaudeModel.sonnet.rawValue
        case .sonnet:
            return ClaudeModel.haiku.rawValue
        case .haiku, .unknown:
            return ClaudeModel.haiku.rawValue
        }
    }

    // MARK: - Complexity Helpers

    /// Returns `true` when the prompt exceeds 500 words or contains complexity keywords.
    private func isComplexPrompt(_ prompt: String) -> Bool {
        let wordCount = prompt.split(whereSeparator: { $0.isWhitespace }).count
        if wordCount > 500 {
            return true
        }
        return !extractMatchedKeywords(from: prompt).isEmpty
    }

    /// Returns the subset of ``complexityKeywords`` present in the prompt (lowercased).
    private func extractMatchedKeywords(from prompt: String) -> Set<String> {
        let lowercased = prompt.lowercased()
        // Tokenise on non-alphanumeric boundaries for accurate whole-word matching
        let words = Set(
            lowercased
                .components(separatedBy: .init(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789").inverted)
                .filter { !$0.isEmpty }
        )
        return words.intersection(Self.complexityKeywords)
    }
}

// MARK: - ClaudeModel RawValue Init

private extension ClaudeModel {
    /// Initialise from a raw string value, returning `nil` for unrecognised strings.
    init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "haiku": self = .haiku
        case "sonnet": self = .sonnet
        case "opus": self = .opus
        default: return nil
        }
    }
}
