import Foundation

/// State of a speech recognition session.
enum SpeechRecognitionState: Sendable, Equatable {
    case idle
    case recording
    case processing
    case error(String)
}

/// Contract for speech-to-text providers.
///
/// Implementations handle microphone capture, speech recognition, and permission management.
/// Results are delivered through an `AsyncStream` of partial transcripts.
protocol SpeechRecognitionProvider: AnyObject {
    /// Current recognition state.
    var state: SpeechRecognitionState { get }

    /// Whether the provider is available on this device/locale.
    var isAvailable: Bool { get }

    /// Whether microphone and speech recognition permissions are granted.
    var isAuthorized: Bool { get }

    /// Requests microphone and speech recognition permissions.
    /// - Returns: `true` if both permissions are granted.
    @discardableResult
    func requestAuthorization() async -> Bool

    /// Starts a recognition session.
    /// - Returns: An `AsyncStream` emitting partial transcription strings as speech is recognized.
    func startRecording() throws -> AsyncStream<String>

    /// Stops the current recognition session and finalizes results.
    func stopRecording()

    /// Current audio power level (0.0–1.0) for waveform visualization.
    var audioLevel: Float { get }
}
