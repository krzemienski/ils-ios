import CoreSpotlight
import Foundation
import ILSShared
import UniformTypeIdentifiers

/// Indexes ILS sessions into macOS Spotlight for system-wide search.
///
/// Sessions appear in Spotlight results with their name, model, and project info.
/// Tapping a Spotlight result opens the session via the `ils://` URL scheme.
@MainActor
final class SpotlightIndexer {
    static let shared = SpotlightIndexer()

    private let domainIdentifier = "com.ils.app.sessions"

    private init() {}

    // MARK: - Indexing

    /// Index an array of sessions into Spotlight.
    ///
    /// Each session is stored as a searchable item with its name, model,
    /// project, and message count as searchable attributes.
    func indexSessions(_ sessions: [ChatSession]) {
        guard !sessions.isEmpty else { return }

        let items = sessions.map { session -> CSSearchableItem in
            let attrs = CSSearchableItemAttributeSet(contentType: UTType.text)
            attrs.title = session.name ?? "Unnamed Session"
            attrs.contentDescription = buildDescription(for: session)
            attrs.keywords = buildKeywords(for: session)
            attrs.relatedUniqueIdentifier = "ils://sessions/\(session.id.uuidString.lowercased())"

            return CSSearchableItem(
                uniqueIdentifier: "session-\(session.id.uuidString.lowercased())",
                domainIdentifier: domainIdentifier,
                attributeSet: attrs
            )
        }

        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error {
                print("[SpotlightIndexer] Failed to index \(items.count) sessions: \(error.localizedDescription)")
            }
        }
    }

    /// Index a single session (e.g., after creation or rename).
    func indexSession(_ session: ChatSession) {
        indexSessions([session])
    }

    // MARK: - De-indexing

    /// Remove a single session from the Spotlight index.
    func deindexSession(_ session: ChatSession) {
        let identifier = "session-\(session.id.uuidString.lowercased())"
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [identifier]) { error in
            if let error {
                print("[SpotlightIndexer] Failed to deindex session: \(error.localizedDescription)")
            }
        }
    }

    /// Remove all ILS sessions from the Spotlight index.
    func deindexAll() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domainIdentifier]) { error in
            if let error {
                print("[SpotlightIndexer] Failed to deindex all: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helpers

    private func buildDescription(for session: ChatSession) -> String {
        var parts: [String] = ["Claude Code session"]
        if let model = session.model {
            parts.append("Model: \(model)")
        }
        if let project = session.projectName {
            parts.append("Project: \(project)")
        }
        if session.messageCount > 0 {
            parts.append("\(session.messageCount) messages")
        }
        return parts.joined(separator: " - ")
    }

    private func buildKeywords(for session: ChatSession) -> [String] {
        var keywords = ["claude", "session", "chat", "code", "ils"]
        if let name = session.name {
            keywords.append(name)
        }
        if let model = session.model {
            keywords.append(model)
        }
        if let project = session.projectName {
            keywords.append(project)
        }
        return keywords
    }
}
