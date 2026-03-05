import Foundation
import Vapor
import ILSShared

/// Service for evaluating automation rule trigger conditions.
///
/// Evaluates whether a rule's trigger matches an event and all conditions are satisfied.
/// Supports trigger types: session_complete, error_occurred, idle_timeout, cost_threshold, context_near_limit.
/// Evaluates conditions with operators: greater_than, less_than, equals, contains.
struct RuleTriggerEvaluator {

    // MARK: - Event Context

    /// Context data for a trigger event evaluation.
    struct TriggerEventContext {
        /// The session that triggered the event.
        let session: ChatSession
        /// The type of trigger event that occurred.
        let triggerType: RuleTriggerType
        /// Additional event-specific data (e.g., error count, idle duration).
        let eventData: [String: Any]

        init(session: ChatSession, triggerType: RuleTriggerType, eventData: [String: Any] = [:]) {
            self.session = session
            self.triggerType = triggerType
            self.eventData = eventData
        }
    }

    // MARK: - Rule Evaluation

    /// Evaluate whether a rule should fire for a given event context.
    /// - Parameters:
    ///   - rule: The automation rule to evaluate.
    ///   - context: The trigger event context containing session and event data.
    /// - Returns: `true` if the rule's trigger matches and all conditions are satisfied, `false` otherwise.
    func shouldFireRule(_ rule: AutomationRule, for context: TriggerEventContext) -> Bool {
        // Rule must be enabled
        guard rule.isEnabled else {
            return false
        }

        // Trigger type must match
        guard rule.triggerType == context.triggerType else {
            return false
        }

        // Session scope must match (if specified)
        if let ruleSessionId = rule.sessionId, ruleSessionId != context.session.id {
            return false
        }

        // Project scope must match (if specified)
        if let ruleProjectName = rule.projectName, ruleProjectName != context.session.projectName {
            return false
        }

        // All conditions must be satisfied
        return evaluateConditions(rule.conditions, for: context)
    }

    // MARK: - Condition Evaluation

    /// Evaluate all conditions for a rule.
    /// - Parameters:
    ///   - conditions: Array of conditions to evaluate.
    ///   - context: The trigger event context.
    /// - Returns: `true` if all conditions are satisfied, `false` if any condition fails.
    private func evaluateConditions(_ conditions: [RuleCondition], for context: TriggerEventContext) -> Bool {
        // If no conditions, rule fires immediately
        guard !conditions.isEmpty else {
            return true
        }

        // All conditions must pass (AND logic)
        for condition in conditions {
            guard evaluateCondition(condition, for: context) else {
                return false
            }
        }

        return true
    }

    /// Evaluate a single condition.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - context: The trigger event context.
    /// - Returns: `true` if the condition is satisfied, `false` otherwise.
    private func evaluateCondition(_ condition: RuleCondition, for context: TriggerEventContext) -> Bool {
        // Extract the field value from session or event data
        guard let fieldValue = extractFieldValue(condition.field, from: context) else {
            return false
        }

        // Evaluate based on operator
        switch condition.operator {
        case .greaterThan:
            return compareNumeric(fieldValue, isGreaterThan: condition.value)
        case .lessThan:
            return compareNumeric(fieldValue, isLessThan: condition.value)
        case .equals:
            return compareEquals(fieldValue, equals: condition.value)
        case .contains:
            return compareContains(fieldValue, contains: condition.value)
        }
    }

    // MARK: - Field Extraction

    /// Extract a field value from the session or event data.
    /// - Parameters:
    ///   - field: The field name to extract.
    ///   - context: The trigger event context.
    /// - Returns: The field value as a string, or nil if not found.
    private func extractFieldValue(_ field: String, from context: TriggerEventContext) -> String? {
        // Check event data first (e.g., "error_count", "idle_duration_minutes")
        if let eventValue = context.eventData[field] {
            return String(describing: eventValue)
        }

        // Fall back to session fields
        switch field {
        case "message_count":
            return String(context.session.messageCount)
        case "cost_usd":
            return context.session.totalCostUSD.map { String($0) }
        case "status":
            return context.session.status.rawValue
        case "model":
            return context.session.model
        case "project_name":
            return context.session.projectName
        case "permission_mode":
            return context.session.permissionMode.rawValue
        case "idle_duration_minutes":
            // Calculate idle duration from lastActiveAt
            let idleMinutes = -context.session.lastActiveAt.timeIntervalSinceNow / 60
            return String(Int(idleMinutes))
        default:
            return nil
        }
    }

    // MARK: - Comparison Operators

    /// Compare numeric values using greater-than operator.
    /// - Parameters:
    ///   - fieldValue: The field value to compare.
    ///   - threshold: The threshold value to compare against.
    /// - Returns: `true` if fieldValue > threshold, `false` otherwise.
    private func compareNumeric(_ fieldValue: String, isGreaterThan threshold: String) -> Bool {
        guard let field = Double(fieldValue), let limit = Double(threshold) else {
            return false
        }
        return field > limit
    }

    /// Compare numeric values using less-than operator.
    /// - Parameters:
    ///   - fieldValue: The field value to compare.
    ///   - threshold: The threshold value to compare against.
    /// - Returns: `true` if fieldValue < threshold, `false` otherwise.
    private func compareNumeric(_ fieldValue: String, isLessThan threshold: String) -> Bool {
        guard let field = Double(fieldValue), let limit = Double(threshold) else {
            return false
        }
        return field < limit
    }

    /// Compare values for equality (case-insensitive string comparison).
    /// - Parameters:
    ///   - fieldValue: The field value to compare.
    ///   - target: The target value to compare against.
    /// - Returns: `true` if fieldValue equals target (case-insensitive), `false` otherwise.
    private func compareEquals(_ fieldValue: String, equals target: String) -> Bool {
        return fieldValue.lowercased() == target.lowercased()
    }

    /// Check if field value contains a substring (case-insensitive).
    /// - Parameters:
    ///   - fieldValue: The field value to search in.
    ///   - substring: The substring to search for.
    /// - Returns: `true` if fieldValue contains substring (case-insensitive), `false` otherwise.
    private func compareContains(_ fieldValue: String, contains substring: String) -> Bool {
        return fieldValue.lowercased().contains(substring.lowercased())
    }

    // MARK: - Convenience Methods

    /// Create a trigger event context for a session completion event.
    /// - Parameter session: The completed session.
    /// - Returns: A trigger event context for session completion.
    static func sessionCompleteContext(session: ChatSession) -> TriggerEventContext {
        return TriggerEventContext(
            session: session,
            triggerType: .sessionComplete
        )
    }

    /// Create a trigger event context for an error occurred event.
    /// - Parameters:
    ///   - session: The session where the error occurred.
    ///   - errorCount: The number of errors that have occurred.
    /// - Returns: A trigger event context for error occurrence.
    static func errorOccurredContext(session: ChatSession, errorCount: Int) -> TriggerEventContext {
        return TriggerEventContext(
            session: session,
            triggerType: .errorOccurred,
            eventData: ["error_count": errorCount]
        )
    }

    /// Create a trigger event context for an idle timeout event.
    /// - Parameters:
    ///   - session: The idle session.
    ///   - idleMinutes: The number of minutes the session has been idle.
    /// - Returns: A trigger event context for idle timeout.
    static func idleTimeoutContext(session: ChatSession, idleMinutes: Int) -> TriggerEventContext {
        return TriggerEventContext(
            session: session,
            triggerType: .idleTimeout,
            eventData: ["idle_duration_minutes": idleMinutes]
        )
    }

    /// Create a trigger event context for a cost threshold event.
    /// - Parameters:
    ///   - session: The session that exceeded the cost threshold.
    ///   - costUSD: The current cost in USD.
    /// - Returns: A trigger event context for cost threshold.
    static func costThresholdContext(session: ChatSession, costUSD: Double) -> TriggerEventContext {
        return TriggerEventContext(
            session: session,
            triggerType: .costThreshold,
            eventData: ["cost_usd": costUSD]
        )
    }

    /// Create a trigger event context for a context near limit event.
    /// - Parameters:
    ///   - session: The session approaching context limit.
    ///   - contextPercentage: The percentage of context used (0-100).
    /// - Returns: A trigger event context for context near limit.
    static func contextNearLimitContext(session: ChatSession, contextPercentage: Int) -> TriggerEventContext {
        return TriggerEventContext(
            session: session,
            triggerType: .contextNearLimit,
            eventData: ["context_percentage": contextPercentage]
        )
    }
}
