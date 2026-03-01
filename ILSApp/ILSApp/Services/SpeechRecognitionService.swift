import Foundation
import Observation

/// Service managing speech recognition lifecycle, recording state, and transcription for UI binding.
///
/// Wraps a ``SpeechRecognitionProvider`` and exposes observable properties for SwiftUI views.
/// Create as a `@State` property in your view for automatic lifecycle management.
///
/// ## Usage
/// ```swift
/// @State private var speechService = SpeechRecognitionService()
/// ```
@Observable
@MainActor
final class SpeechRecognitionService {

    // MARK: - Recording State

    /// High-level recording state for UI binding.
    enum RecordingState: Equatable {
        case idle
        case requestingPermission
        case recording
        case stopping
        case error(String)
    }

    /// Permission status for speech recognition and microphone.
    enum PermissionStatus: Equatable {
        case notDetermined
        case authorized
        case denied
    }

    // MARK: - Observable Properties

    /// Current recording state.
    var recordingState: RecordingState = .idle

    /// Transcribed text from the current or most recent recording session.
    var transcribedText: String = ""

    /// Current audio power level (0.0–1.0) for waveform visualization.
    var audioLevel: Float = 0.0

    /// Current permission status.
    var permissionStatus: PermissionStatus = .notDetermined

    /// Whether speech recognition is currently recording.
    var isRecording: Bool {
        recordingState == .recording
    }

    /// Whether the provider is available on this device.
    var isAvailable: Bool {
        provider.isAvailable
    }

    // MARK: - Private

    @ObservationIgnored private let provider: SpeechRecognitionProvider
    @ObservationIgnored private var transcriptionTask: Task<Void, Never>?
    @ObservationIgnored private var audioLevelTask: Task<Void, Never>?

    // MARK: - Init

    init(provider: SpeechRecognitionProvider? = nil) {
        self.provider = provider ?? AppleSpeechProvider()
        // Sync initial permission status
        if self.provider.isAuthorized {
            permissionStatus = .authorized
        }
    }

    deinit {
        transcriptionTask?.cancel()
        audioLevelTask?.cancel()
    }

    // MARK: - Permissions

    /// Requests microphone and speech recognition permissions.
    /// - Returns: `true` if both permissions are granted.
    @discardableResult
    func requestPermissions() async -> Bool {
        recordingState = .requestingPermission
        let granted = await provider.requestAuthorization()
        permissionStatus = granted ? .authorized : .denied
        recordingState = .idle
        return granted
    }

    // MARK: - Recording

    /// Starts a speech recognition session.
    ///
    /// Transcribed text updates in real-time via ``transcribedText``.
    /// Audio levels update at ~60fps via ``audioLevel``.
    func startRecording() async throws {
        if !(permissionStatus == .authorized || provider.isAuthorized) {
            let granted = await requestPermissions()
            guard granted else {
                recordingState = .error("Microphone or speech recognition access denied")
                throw SpeechError.notAuthorized
            }
        }

        // Reset state
        transcribedText = ""
        audioLevel = 0.0

        let stream: AsyncStream<String>
        do {
            stream = try provider.startRecording()
        } catch {
            recordingState = .error(error.localizedDescription)
            throw error
        }

        recordingState = .recording

        // Consume transcription stream
        transcriptionTask = Task { [weak self] in
            for await text in stream {
                guard let self, !Task.isCancelled else { break }
                self.transcribedText = text
            }
        }

        // Poll audio level for waveform visualization (~60fps)
        audioLevelTask = Task { [weak self] in
            while let self, !Task.isCancelled, self.isRecording {
                self.audioLevel = self.provider.audioLevel
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    /// Stops the current recording session and finalizes transcription.
    func stopRecording() {
        guard isRecording else { return }
        recordingState = .stopping
        provider.stopRecording()
        cleanupTasks()
        audioLevel = 0.0
        recordingState = .idle
    }

    /// Cancels the current recording session and discards transcription.
    func cancelRecording() {
        provider.stopRecording()
        cleanupTasks()
        transcribedText = ""
        audioLevel = 0.0
        recordingState = .idle
    }

    // MARK: - Private

    private func cleanupTasks() {
        transcriptionTask?.cancel()
        transcriptionTask = nil
        audioLevelTask?.cancel()
        audioLevelTask = nil
    }
}
