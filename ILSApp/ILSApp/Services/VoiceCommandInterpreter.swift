import Foundation
import NaturalLanguage
import Observation

// MARK: - VoiceCommandContext

/// Contextual information that influences how voice commands are interpreted.
struct VoiceCommandContext: Sendable {
    /// Whether there are pending permission requests in the current session.
    let hasPendingPermissions: Bool
    /// Number of pending permission requests.
    let pendingPermissionCount: Int
    /// The currently active screen, if known.
    let activeScreen: ActiveScreen?

    init(
        hasPendingPermissions: Bool = false,
        pendingPermissionCount: Int = 0,
        activeScreen: ActiveScreen? = nil
    ) {
        self.hasPendingPermissions = hasPendingPermissions
        self.pendingPermissionCount = pendingPermissionCount
        self.activeScreen = activeScreen
    }
}

// MARK: - InterpretationRecord

/// A record of a single interpretation attempt for debugging and analytics.
struct InterpretationRecord: Sendable {
    let timestamp: Date
    let transcription: String
    let result: VoiceCommandMatch
    let durationMs: Int
}

// MARK: - VoiceCommandInterpreter

/// Service that matches transcribed speech text to predefined voice commands.
///
/// Uses a multi-pass matching strategy:
/// 1. Normalize input text (lowercase, trim whitespace/punctuation)
/// 2. Exact phrase match against `VoiceCommandCatalog` phrases
/// 3. Keyword extraction with weighted scoring (action words 2x, target words 1.5x)
/// 4. `FuzzyMatcher` fallback on command display names
///
/// Confidence thresholds are configurable via `UserDefaults`.
@MainActor
@Observable
class VoiceCommandInterpreter {

    // MARK: - Confidence Thresholds

    /// Minimum confidence for high-confidence auto-execution of non-destructive commands.
    var highConfidenceThreshold: Double {
        UserDefaults.standard.double(forKey: "voiceCommandHighConfidence").clamped(fallback: 0.8)
    }

    /// Minimum confidence to show a confirmation prompt.
    var mediumConfidenceThreshold: Double {
        UserDefaults.standard.double(forKey: "voiceCommandMediumConfidence").clamped(fallback: 0.5)
    }

    /// Recent interpretation attempts, most-recent first. Capped at 50 entries.
    private(set) var interpretationHistory: [InterpretationRecord] = []

    // MARK: - Private State

    private let tokenizer = NLTokenizer(unit: .word)
    private let catalog = VoiceCommandCatalog.allCommands

    /// Action keywords receive a 2x weight boost during keyword scoring.
    private static let actionKeywords: Set<String> = [
        "approve", "allow", "accept", "deny", "reject", "block",
        "delete", "remove", "create", "new", "start", "open",
        "show", "go", "run", "trigger", "execute", "summarize", "status"
    ]

    /// Target keywords receive a 1.5x weight boost during keyword scoring.
    private static let targetKeywords: Set<String> = [
        "session", "sessions", "home", "settings", "system",
        "workflows", "permission", "permissions", "workflow",
        "all", "everything"
    ]

    /// Common speech recognition filler words to strip before matching.
    private static let fillerWords: Set<String> = [
        "um", "uh", "like", "please", "hey", "ok", "okay",
        "can", "you", "could", "would", "the", "a", "an",
        "just", "maybe", "so", "well", "actually", "basically"
    ]

    /// Common speech-to-text misrecognition corrections.
    private static let corrections: [String: String] = [
        "a prove": "approve",
        "except": "accept",
        "denied": "deny",
        "sessions": "session",
        "permits": "permission",
        "allowed": "allow",
        "removed": "remove",
        "deleted": "delete",
        "navigation": "navigate",
        "navigates": "navigate",
        "goes": "go",
        "shows": "show",
        "creates": "create",
        "starts": "start",
        "opens": "open",
        "running": "run",
        "triggered": "trigger",
        "summarized": "summarize",
        "summarizes": "summarize"
    ]

    // MARK: - Public API

    /// Interprets a transcribed text string and returns the best matching voice command.
    ///
    /// - Parameters:
    ///   - transcription: Raw transcribed text from speech recognition.
    ///   - context: Optional contextual information to influence matching.
    /// - Returns: A `VoiceCommandMatch` indicating the result.
    func interpret(_ transcription: String, context: VoiceCommandContext = VoiceCommandContext()) -> VoiceCommandMatch {
        let start = CFAbsoluteTimeGetCurrent()
        let normalized = normalize(transcription)

        guard !normalized.isEmpty else {
            let result = VoiceCommandMatch.noMatch(suggestions: suggestionsForContext(context))
            recordInterpretation(transcription: transcription, result: result, start: start)
            return result
        }

        // Edge case: single character or very short input is unlikely to be a valid command
        if normalized.count < 2 {
            let result = VoiceCommandMatch.noMatch(suggestions: suggestionsForContext(context))
            recordInterpretation(transcription: transcription, result: result, start: start)
            return result
        }

        // Edge case: excessively long input — likely dictation, not a command
        if normalized.count > 200 {
            let result = VoiceCommandMatch.noMatch(suggestions: suggestionsForContext(context))
            recordInterpretation(transcription: transcription, result: result, start: start)
            return result
        }

        // Pass 1: Exact phrase match
        if let exactResult = exactPhraseMatch(normalized) {
            recordInterpretation(transcription: transcription, result: exactResult, start: start)
            return exactResult
        }

        // Pass 2: Keyword-weighted scoring
        let keywordResults = keywordMatch(normalized, context: context)
        if let keywordResult = evaluateScoredMatches(keywordResults) {
            recordInterpretation(transcription: transcription, result: keywordResult, start: start)
            return keywordResult
        }

        // Pass 3: Fuzzy match on display names
        let fuzzyResults = fuzzyDisplayNameMatch(normalized)
        if let fuzzyResult = evaluateScoredMatches(fuzzyResults) {
            recordInterpretation(transcription: transcription, result: fuzzyResult, start: start)
            return fuzzyResult
        }

        // No match — return suggestions
        let suggestions = suggestionsForContext(context)
        let result = VoiceCommandMatch.noMatch(suggestions: suggestions)
        recordInterpretation(transcription: transcription, result: result, start: start)
        return result
    }

    /// Returns contextually relevant command suggestions.
    ///
    /// When permissions are pending, permission commands are prioritized.
    /// Otherwise returns the most commonly useful commands.
    func suggestionsForContext(_ context: VoiceCommandContext) -> [VoiceCommand] {
        var suggestions: [VoiceCommand] = []

        if context.hasPendingPermissions {
            // Prioritize permission commands when permissions are pending
            suggestions.append(contentsOf: VoiceCommandCatalog.commands(for: .permission).prefix(2))
        }

        // Fill remaining slots with general-purpose commands
        let generalCommands = catalog.filter { cmd in
            !suggestions.contains(where: { $0.id == cmd.id })
        }

        for command in generalCommands {
            if suggestions.count >= 3 { break }
            suggestions.append(command)
        }

        return Array(suggestions.prefix(3))
    }

    /// Clears the interpretation history.
    func clearHistory() {
        interpretationHistory.removeAll()
    }

    // MARK: - Text Normalization

    /// Normalizes transcribed text for matching: lowercases, trims whitespace,
    /// strips leading/trailing punctuation, removes filler words, and applies
    /// common speech-to-text corrections.
    private func normalize(_ text: String) -> String {
        var result = text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip leading/trailing punctuation
        let punctuation = CharacterSet.punctuationCharacters.union(.symbols)
        while let first = result.unicodeScalars.first, punctuation.contains(first) {
            result = String(result.dropFirst())
        }
        while let last = result.unicodeScalars.last, punctuation.contains(last) {
            result = String(result.dropLast())
        }

        result = result.trimmingCharacters(in: .whitespaces)

        // Remove filler words
        let words = result.split(separator: " ").map(String.init)
        let filtered = words.filter { !Self.fillerWords.contains($0) }

        // Apply speech-to-text corrections
        let corrected = filtered.map { word in
            Self.corrections[word] ?? word
        }

        // Also check multi-word corrections (e.g. "a prove" → "approve")
        var joined = corrected.joined(separator: " ")
        for (wrong, right) in Self.corrections {
            if wrong.contains(" ") {
                joined = joined.replacingOccurrences(of: wrong, with: right)
            }
        }

        return joined.trimmingCharacters(in: .whitespaces)
    }

    /// Tokenizes text into individual words using NLTokenizer.
    private func tokenize(_ text: String) -> [String] {
        tokenizer.string = text
        var tokens: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            tokens.append(String(text[range]).lowercased())
            return true
        }
        return tokens
    }

    // MARK: - Pass 1: Exact Phrase Match

    /// Checks if the normalized text exactly matches any command's registered phrases.
    private func exactPhraseMatch(_ normalized: String) -> VoiceCommandMatch? {
        for command in catalog {
            for phrase in command.phrases {
                if normalized == phrase.lowercased() {
                    return .exact(command, confidence: 1.0)
                }
            }
        }

        // Also check if the normalized text contains an exact phrase as a substring
        for command in catalog {
            for phrase in command.phrases {
                let lowerPhrase = phrase.lowercased()
                if normalized.contains(lowerPhrase) && lowerPhrase.count >= 3 {
                    let coverage = Double(lowerPhrase.count) / Double(normalized.count)
                    if coverage >= 0.5 {
                        return .exact(command, confidence: 0.85 + coverage * 0.1)
                    }
                }
            }
        }

        return nil
    }

    // MARK: - Pass 2: Keyword Weighted Scoring

    /// Scores each command based on keyword overlap with weighted importance.
    private func keywordMatch(
        _ normalized: String,
        context: VoiceCommandContext
    ) -> [(VoiceCommand, Double)] {
        let inputTokens = tokenize(normalized)
        guard !inputTokens.isEmpty else { return [] }

        var scores: [(VoiceCommand, Double)] = []

        for command in catalog {
            var score = 0.0
            var maxPossibleScore = 0.0

            // Score against each phrase's keywords
            let phraseTokens = command.phrases.flatMap { tokenize($0) }
            let uniquePhraseTokens = Set(phraseTokens)

            for token in uniquePhraseTokens {
                let weight = keywordWeight(for: token)
                maxPossibleScore += weight
            }

            for inputToken in inputTokens {
                if uniquePhraseTokens.contains(inputToken) {
                    score += keywordWeight(for: inputToken)
                }
            }

            // Contextual boost: permission commands score higher when permissions are pending
            if context.hasPendingPermissions && command.category == .permission {
                score *= 1.3
            }

            let normalizedScore = maxPossibleScore > 0 ? min(score / maxPossibleScore, 1.0) : 0.0

            if normalizedScore > 0.1 {
                scores.append((command, normalizedScore * 0.9)) // Cap at 0.9 for keyword matches
            }
        }

        return scores.sorted { $0.1 > $1.1 }
    }

    /// Returns the weight multiplier for a keyword.
    private func keywordWeight(for token: String) -> Double {
        if Self.actionKeywords.contains(token) {
            return 2.0
        } else if Self.targetKeywords.contains(token) {
            return 1.5
        }
        return 1.0
    }

    // MARK: - Pass 3: Fuzzy Display Name Match

    /// Uses FuzzyMatcher to score the input against command display names.
    private func fuzzyDisplayNameMatch(_ normalized: String) -> [(VoiceCommand, Double)] {
        var scores: [(VoiceCommand, Double)] = []

        for command in catalog {
            let nameScore = FuzzyMatcher.score(query: normalized, in: command.displayName)
            let descScore = FuzzyMatcher.score(query: normalized, in: command.description)
            let bestScore = max(nameScore, descScore)

            if bestScore > 0.1 {
                // Scale fuzzy scores to a lower band (max 0.75) since they're less precise
                scores.append((command, bestScore * 0.75))
            }
        }

        return scores.sorted { $0.1 > $1.1 }
    }

    // MARK: - Match Evaluation

    /// Evaluates a list of scored matches and returns the appropriate `VoiceCommandMatch`.
    ///
    /// - If the top match is well above the second, returns `.fuzzy` with that command.
    /// - If multiple matches have similar scores, returns `.ambiguous`.
    /// - If no match exceeds the medium threshold, returns `nil` (fall through to next pass).
    private func evaluateScoredMatches(
        _ scores: [(VoiceCommand, Double)]
    ) -> VoiceCommandMatch? {
        guard let top = scores.first, top.1 >= mediumConfidenceThreshold else {
            return nil
        }

        // Check for ambiguity: if second-best is within 10% of top, it's ambiguous
        if scores.count >= 2 {
            let second = scores[1]
            let gap = top.1 - second.1
            if gap < 0.1 && second.1 >= mediumConfidenceThreshold {
                let candidates = scores
                    .prefix(3)
                    .filter { $0.1 >= mediumConfidenceThreshold }
                    .map { $0.0 }
                return .ambiguous(Array(candidates))
            }
        }

        return .fuzzy(top.0, confidence: top.1)
    }

    // MARK: - History

    /// Records an interpretation attempt in the history buffer.
    private func recordInterpretation(
        transcription: String,
        result: VoiceCommandMatch,
        start: CFAbsoluteTime
    ) {
        let durationMs = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
        let record = InterpretationRecord(
            timestamp: Date(),
            transcription: transcription,
            result: result,
            durationMs: durationMs
        )

        interpretationHistory.insert(record, at: 0)
        if interpretationHistory.count > 50 {
            interpretationHistory = Array(interpretationHistory.prefix(50))
        }
    }
}

// MARK: - Double + Clamped Fallback

private extension Double {
    /// Returns `self` if it is a valid positive value, otherwise returns `fallback`.
    func clamped(fallback: Double) -> Double {
        self > 0.0 && self <= 1.0 ? self : fallback
    }
}
