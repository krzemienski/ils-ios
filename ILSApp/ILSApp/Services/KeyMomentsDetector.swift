import Foundation

/// A suggestion that a specific message may be worth bookmarking as a key moment.
///
/// Produced by ``KeyMomentsDetector`` when heuristic analysis of a ``ChatMessage``
/// detects characteristics associated with high-value content such as architectural
/// decisions, code solutions, or substantive assistant explanations.
struct KeyMomentSuggestion: Equatable {
    /// The ID of the message that triggered the suggestion.
    let messageId: UUID
    /// Human-readable explanation of why this message was flagged.
    let reason: String
}

/// Stateless heuristic analyser that inspects ``ChatMessage`` objects and returns
/// a ``KeyMomentSuggestion`` when the message content meets one or more criteria
/// associated with key moments in a development session.
///
/// Detection heuristics (applied in priority order):
/// 1. **Code block length** — a fenced code block of ≥ 10 lines suggests a substantive
///    implementation.
/// 2. **Keyword presence** — messages containing domain-significant terms
///    (*architecture*, *decision*, *solution*, *fixed*, *configured*, *important*)
///    likely capture an important discussion point.
/// 3. **Long assistant response** — assistant messages longer than 500 characters
///    typically contain detailed explanations worth preserving.
enum KeyMomentsDetector {

    // MARK: - Configuration

    private static let codeBlockMinLines = 10
    private static let longMessageMinChars = 500

    /// Keywords that signal an architecturally or operationally significant message.
    private static let significantKeywords: [String] = [
        "architecture",
        "decision",
        "solution",
        "fixed",
        "configured",
        "important",
    ]

    // MARK: - Public API

    /// Analyses `message` and returns a suggestion when heuristics are triggered.
    ///
    /// Returns `nil` for system messages and for messages that do not meet any
    /// detection threshold.
    ///
    /// - Parameter message: The ``ChatMessage`` to inspect.
    /// - Returns: A ``KeyMomentSuggestion`` if the message is a candidate key moment,
    ///   otherwise `nil`.
    static func analyze(_ message: ChatMessage) -> KeyMomentSuggestion? {
        guard !message.isSystem else { return nil }
        let text = message.text

        if let reason = detectCodeBlock(in: text) {
            return KeyMomentSuggestion(messageId: message.id, reason: reason)
        }

        if let reason = detectKeyword(in: text) {
            return KeyMomentSuggestion(messageId: message.id, reason: reason)
        }

        if !message.isUser, let reason = detectLongAssistantMessage(text) {
            return KeyMomentSuggestion(messageId: message.id, reason: reason)
        }

        return nil
    }

    /// Analyses a collection of messages and returns suggestions for any that
    /// qualify as key moments.
    ///
    /// - Parameter messages: The messages to inspect.
    /// - Returns: An array of suggestions, one per qualifying message, in the
    ///   same order as the input.
    static func analyze(_ messages: [ChatMessage]) -> [KeyMomentSuggestion] {
        messages.compactMap { analyze($0) }
    }

    // MARK: - Heuristics

    /// Returns a reason string when the message contains a fenced code block of
    /// at least ``codeBlockMinLines`` lines, otherwise returns `nil`.
    private static func detectCodeBlock(in text: String) -> String? {
        // Matches opening ``` fence (with optional language specifier) through
        // the corresponding closing ``` fence.
        let pattern = "```[^\\n]*\\n([\\s\\S]*?)```"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let nsText = text as NSString
        let range  = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, range: range)

        for match in matches {
            guard let bodyRange = Range(match.range(at: 1), in: text) else { continue }
            let body = String(text[bodyRange])
            let lineCount = body.components(separatedBy: .newlines).count
            if lineCount >= codeBlockMinLines {
                return "Contains a code block with \(lineCount) lines"
            }
        }
        return nil
    }

    /// Returns a reason string when the message contains one of the predefined
    /// significant keywords (case-insensitive whole-word match), otherwise `nil`.
    private static func detectKeyword(in text: String) -> String? {
        let lowered = text.lowercased()
        for keyword in significantKeywords {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: keyword))\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(lowered.startIndex..., in: lowered)
            if regex.firstMatch(in: lowered, range: range) != nil {
                return "Contains significant keyword: \"\(keyword)\""
            }
        }
        return nil
    }

    /// Returns a reason string when `text` exceeds ``longMessageMinChars`` characters,
    /// otherwise `nil`.  Only intended for assistant (non-user) messages.
    private static func detectLongAssistantMessage(_ text: String) -> String? {
        let count = text.count
        guard count > longMessageMinChars else { return nil }
        return "Long assistant response (\(count) characters)"
    }
}
