import SwiftUI
import ILSShared

enum SessionExporter {
    /// Generate plain-text summary string for a session.
    static func exportText(for session: ChatSession) -> String {
        "Session: \(session.name ?? "Unnamed")\nModel: \(session.model)\nCreated: \(DateFormatters.dateTime.string(from: session.createdAt))\nMessages: \(session.messageCount)"
    }
}
