import Foundation

// MARK: - Session Comparison DTOs

/// A session paired with its complete message history for comparison purposes.
public struct SessionWithMessages: Codable, Sendable {
    /// The session metadata.
    public let session: ChatSession
    /// All messages in the session, in chronological order.
    public let messages: [Message]

    public init(session: ChatSession, messages: [Message]) {
        self.session = session
        self.messages = messages
    }
}

/// Result of a side-by-side comparison between two sessions.
///
/// Contains full session metadata and message histories for both sessions,
/// enabling UI to render parallel message threads and compute diff metrics.
public struct SessionComparisonResult: Codable, Sendable {
    /// First session to compare.
    public let sessionA: ChatSession
    /// Second session to compare.
    public let sessionB: ChatSession
    /// All messages from the first session, in chronological order.
    public let messagesA: [Message]
    /// All messages from the second session, in chronological order.
    public let messagesB: [Message]

    public init(
        sessionA: ChatSession,
        sessionB: ChatSession,
        messagesA: [Message],
        messagesB: [Message]
    ) {
        self.sessionA = sessionA
        self.sessionB = sessionB
        self.messagesA = messagesA
        self.messagesB = messagesB
    }

    /// Message count difference between session A and session B.
    public var messageCountDelta: Int {
        messagesA.count - messagesB.count
    }

    /// Cost difference in USD between session A and session B.
    public var costDeltaUSD: Double? {
        guard let costA = sessionA.totalCostUSD, let costB = sessionB.totalCostUSD else {
            return nil
        }
        return costA - costB
    }
}

/// A record of two sessions that were recently compared together.
///
/// Used to populate a "recently compared" list for quick re-comparison.
public struct RecentlyComparedPair: Codable, Identifiable, Sendable {
    /// Unique identifier for this comparison pair record.
    public let id: UUID
    /// ID of the first session in the pair.
    public let sessionAId: UUID
    /// ID of the second session in the pair.
    public let sessionBId: UUID
    /// Display name of the first session (for rendering without fetching).
    public let sessionAName: String?
    /// Display name of the second session (for rendering without fetching).
    public let sessionBName: String?
    /// When this pair was last compared.
    public let comparedAt: Date

    public init(
        id: UUID = UUID(),
        sessionAId: UUID,
        sessionBId: UUID,
        sessionAName: String? = nil,
        sessionBName: String? = nil,
        comparedAt: Date = Date()
    ) {
        self.id = id
        self.sessionAId = sessionAId
        self.sessionBId = sessionBId
        self.sessionAName = sessionAName
        self.sessionBName = sessionBName
        self.comparedAt = comparedAt
    }
}
