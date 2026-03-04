import Foundation
import Observation
import ILSShared

/// View model for listing and managing session recordings.
///
/// Fetches the recording list for a given session, supports starting and stopping
/// recordings, deleting recordings, and exporting recording data. Follows the
/// project's unidirectional data-flow convention (@Observable + APIClient).
///
/// ## Topics
/// ### Properties
/// - ``recordings`` - All recordings for the current session (newest first)
/// - ``isLoading`` - Whether a fetch or mutation is in progress
/// - ``error`` - Most recent error from any operation
/// - ``activeRecording`` - The currently active (status=recording) recording
/// - ``exportData`` - Raw export bytes from the most recent export call
///
/// ### Operations
/// - ``configure(client:)`` - Inject the API client
/// - ``loadRecordings(sessionId:)`` - Fetch recordings for a session
/// - ``startRecording(sessionId:name:)`` - Begin a new recording
/// - ``stopRecording(recordingId:)`` - Stop an active recording
/// - ``deleteRecording(recordingId:)`` - Permanently delete a recording
/// - ``exportRecording(recordingId:format:redact:)`` - Export recording data
@Observable
@MainActor
class SessionRecordingViewModel {

    // MARK: - Observable Properties

    /// All recordings for the current session, ordered newest-first.
    var recordings: [SessionRecording] = []

    /// Whether any fetch or mutation is currently in progress.
    var isLoading = false

    /// Most recent error from any API operation, if any.
    var error: Error?

    /// Raw bytes from the most recent export call (JSON or Markdown text).
    var exportData: Data?

    // MARK: - Computed Properties

    /// The currently active recording (status == .recording), if any.
    var activeRecording: SessionRecording? {
        recordings.first { $0.status == .recording }
    }

    // MARK: - Private State

    private var client: APIClient?

    // MARK: - Configuration

    /// Inject the API client. Must be called before any data operations.
    func configure(client: APIClient) {
        self.client = client
    }

    // MARK: - Load Recordings

    /// Fetch all recordings for the given session, replacing the current list.
    ///
    /// - Parameter sessionId: The UUID string of the session whose recordings to load.
    func loadRecordings(sessionId: String) async {
        guard let client else { return }
        isLoading = true
        error = nil

        do {
            let response: APIResponse<RecordingListResponse> = try await client.get(
                "/sessions/\(sessionId)/recordings"
            )
            if let data = response.data {
                recordings = data.recordings
            }
        } catch {
            self.error = error
        }

        isLoading = false
    }

    // MARK: - Start Recording

    /// Begin a new recording for the given session.
    ///
    /// - Parameters:
    ///   - sessionId: UUID string of the session to record.
    ///   - name: Optional human-readable name for the recording.
    func startRecording(sessionId: String, name: String? = nil) async {
        guard let client else { return }
        isLoading = true
        error = nil

        do {
            let response: APIResponse<SessionRecording> = try await client.post(
                "/sessions/\(sessionId)/recordings",
                body: CreateRecordingBody(name: name)
            )
            if let recording = response.data {
                recordings.insert(recording, at: 0)
            }
        } catch {
            self.error = error
        }

        isLoading = false
    }

    // MARK: - Stop Recording

    /// Stop an active recording, updating its status to stopped.
    ///
    /// - Parameter recordingId: UUID string of the recording to stop.
    func stopRecording(recordingId: String) async {
        guard let client else { return }
        isLoading = true
        error = nil

        do {
            let response: APIResponse<SessionRecording> = try await client.post(
                "/recordings/\(recordingId)/stop",
                body: EmptyBody()
            )
            if let updated = response.data,
               let idx = recordings.firstIndex(where: { $0.id == recordingId }) {
                recordings[idx] = updated
            }
        } catch {
            self.error = error
        }

        isLoading = false
    }

    // MARK: - Delete Recording

    /// Permanently delete a recording.
    ///
    /// - Parameter recordingId: UUID string of the recording to delete.
    func deleteRecording(recordingId: String) async {
        guard let client else { return }
        isLoading = true
        error = nil

        do {
            let _: APIResponse<DeletedResponse> = try await client.delete(
                "/recordings/\(recordingId)"
            )
            recordings.removeAll { $0.id == recordingId }
        } catch {
            self.error = error
        }

        isLoading = false
    }

    // MARK: - Export Recording

    /// Export a recording as JSON or Markdown, with optional content redaction.
    ///
    /// The exported bytes are stored in ``exportData`` after a successful call.
    ///
    /// - Parameters:
    ///   - recordingId: UUID string of the recording to export.
    ///   - format: Export format — `"json"` (default) or `"markdown"`.
    ///   - redact: When `true`, sensitive message content is stripped before export.
    func exportRecording(recordingId: String, format: String = "json", redact: Bool = false) async {
        guard let client else { return }
        isLoading = true
        error = nil
        exportData = nil

        do {
            exportData = try await client.getRawData(
                "/recordings/\(recordingId)/export?format=\(format)&redact=\(redact)"
            )
        } catch {
            self.error = error
        }

        isLoading = false
    }
}

// MARK: - Private Request Body Types

/// Optional request body sent when starting a new recording.
private struct CreateRecordingBody: Encodable {
    var name: String?
}
