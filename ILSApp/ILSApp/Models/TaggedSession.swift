import Foundation
import ILSShared

/// A chat session annotated with its source backend's identity for display in a
/// unified multi-backend session list.
///
/// ``TaggedSession`` wraps a ``ChatSession`` and adds the originating backend's
/// ``id``, ``name``, and ``colorHex`` so that each row in the unified list can
/// show a color-coded backend label without performing an additional lookup.
struct TaggedSession: Identifiable, Hashable {
    /// Stable identity combining backend and session IDs.
    ///
    /// Using a composite string key ensures uniqueness across backends whose
    /// sessions could otherwise share UUIDs in theory.
    var id: String { "\(backendId.uuidString)-\(session.id.uuidString)" }

    /// The underlying chat session.
    let session: ChatSession

    /// Identifier of the ``BackendConnection`` this session belongs to.
    let backendId: UUID

    /// Human-readable name of the originating backend (e.g., "Work Mac").
    let backendName: String

    /// Hex color string for the originating backend (e.g., "#4A90E2").
    let backendColorHex: String

    /// Creates a tagged session.
    /// - Parameters:
    ///   - session: The underlying chat session.
    ///   - backendId: Identifier of the originating ``BackendConnection``.
    ///   - backendName: Display name of the originating backend.
    ///   - backendColorHex: Hex color for the originating backend.
    init(session: ChatSession, backendId: UUID, backendName: String, backendColorHex: String) {
        self.session = session
        self.backendId = backendId
        self.backendName = backendName
        self.backendColorHex = backendColorHex
    }

    // MARK: - Forwarded Convenience Properties

    /// Display name forwarded from the underlying session.
    var displayName: String { session.displayName }

    /// Status forwarded from the underlying session.
    var status: SessionStatus { session.status }

    /// Last-active timestamp forwarded from the underlying session.
    var lastActiveAt: Date { session.lastActiveAt }
}
