import Foundation
import GRDB

// MARK: - PermissionStats

/// Aggregated statistics for permission decisions.
struct PermissionStats: Sendable {
    /// Total number of permissions approved (including auto-approved).
    let totalApproved: Int
    /// Total number of permissions denied.
    let totalDenied: Int
    /// Number of permissions approved automatically by an auto-approve rule.
    let totalAutoApproved: Int
    /// Ratio of approved to total decisions. 0.0 if no decisions recorded.
    let approvalRate: Double
    /// Map of tool name to decision count, top 5 tools by frequency.
    let topTools: [String: Int]
}

// MARK: - PermissionReasonCode

/// Machine-readable reason codes explaining why a permission was denied or blocked.
enum PermissionReasonCode: String, CaseIterable, Sendable {
    case policyViolation = "policy_violation"
    case highRiskBlocked = "high_risk_blocked"
    case patternDenied = "pattern_denied"
    case userDenied = "user_denied"
    case timeout = "timeout"
    case policyAutoApprove = "policy_auto_approve"
    case unknown = "unknown"

    /// Initialise from a raw string, falling back to ``unknown`` for unrecognised values.
    init(rawString: String?) {
        guard let rawString else { self = .unknown; return }
        self = PermissionReasonCode(rawValue: rawString) ?? .unknown
    }

    /// Human-readable label for display in badges and filters.
    var displayLabel: String {
        switch self {
        case .policyViolation: return "Policy Violation"
        case .highRiskBlocked: return "High Risk Blocked"
        case .patternDenied: return "Pattern Denied"
        case .userDenied: return "User Denied"
        case .timeout: return "Timeout"
        case .policyAutoApprove: return "Auto-Approved"
        case .unknown: return "Unknown"
        }
    }

    /// SF Symbol icon name for the reason code.
    var iconName: String {
        switch self {
        case .policyViolation: return "exclamationmark.shield.fill"
        case .highRiskBlocked: return "hand.raised.fill"
        case .patternDenied: return "nosign"
        case .userDenied: return "person.fill.xmark"
        case .timeout: return "clock.badge.xmark"
        case .policyAutoApprove: return "bolt.shield.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    /// Reason codes that are relevant for denied/blocked entries only.
    static var deniedCodes: [PermissionReasonCode] {
        [.policyViolation, .highRiskBlocked, .patternDenied, .userDenied, .timeout]
    }
}

// MARK: - PermissionHistoryEntry

/// GRDB-backed record for storing the history of permission decisions made by the user.
struct PermissionHistoryEntry: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "permission_history"

    /// UUID as string — primary key.
    let id: String
    /// UUID string of the chat session in which this decision was made.
    var sessionId: String
    /// The tool name that requested permission (e.g. "Bash", "Read", "Write").
    var toolName: String
    /// First 200 characters of the formatted tool input for display purposes.
    var toolInputSummary: String
    /// The decision made: "allow" or "deny".
    var decision: String
    /// Whether this decision was made automatically by an auto-approve rule.
    var isAutoApproved: Bool
    /// When the decision was recorded.
    var timestamp: Date
    /// Machine-readable reason code for the decision (e.g. "policy_violation", "high_risk_blocked").
    var reasonCode: String?

    init(
        id: String = UUID().uuidString,
        sessionId: String,
        toolName: String,
        toolInputSummary: String,
        decision: String,
        isAutoApproved: Bool,
        timestamp: Date = Date(),
        reasonCode: String? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.toolName = toolName
        self.toolInputSummary = String(toolInputSummary.prefix(200))
        self.decision = decision
        self.isAutoApproved = isAutoApproved
        self.timestamp = timestamp
        self.reasonCode = reasonCode
    }

    /// Parsed ``PermissionReasonCode`` from the raw string.
    var parsedReasonCode: PermissionReasonCode {
        PermissionReasonCode(rawString: reasonCode)
    }
}
