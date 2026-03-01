#if os(iOS)
import Foundation
import Speech
import AVFoundation

/// Speech-to-text provider using iOS Speech framework with on-device recognition when available.
final class AppleSpeechProvider: NSObject, SpeechRecognitionProvider {

    // MARK: - Properties

    private(set) var state: SpeechRecognitionState = .idle
    private(set) var audioLevel: Float = 0.0

    private let speechRecognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var streamContinuation: AsyncStream<String>.Continuation?

    // MARK: - Init

    override init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
        super.init()
        speechRecognizer?.delegate = self
    }

    // MARK: - SpeechRecognitionProvider

    var isAvailable: Bool {
        speechRecognizer?.isAvailable ?? false
    }

    var isAuthorized: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
            && AVAudioApplication.shared.recordPermission == .granted
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        let speechGranted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        guard speechGranted else { return false }

        let micGranted: Bool
        if AVAudioApplication.shared.recordPermission == .granted {
            micGranted = true
        } else {
            micGranted = await AVAudioApplication.requestRecordPermission()
        }

        return micGranted
    }

    func startRecording() throws -> AsyncStream<String> {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            state = .error("Speech recognition unavailable")
            throw SpeechError.unavailable
        }

        // Cancel any in-flight session
        stopRecording()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        // Prefer on-device recognition for privacy (iOS 13+)
        if speechRecognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        // Add contextual hints for programming vocabulary
        request.contextualStrings = [
            "function", "variable", "struct", "class", "enum", "protocol",
            "async", "await", "import", "return", "guard", "let", "var",
            "Swift", "Python", "JavaScript", "TypeScript", "React",
            "API", "HTTP", "JSON", "URL", "UUID", "SQL", "CLI", "SDK",
            "git", "commit", "merge", "branch", "pull request",
            "refactor", "debug", "deploy", "build", "test"
        ]

        self.recognitionRequest = request

        let stream = AsyncStream<String> { continuation in
            self.streamContinuation = continuation
            continuation.onTermination = { @Sendable _ in
                // Clean up if consumer cancels
            }
        }

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Install tap for audio data
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            self?.updateAudioLevel(buffer: buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let text = result.bestTranscription.formattedString
                self.streamContinuation?.yield(text)

                if result.isFinal {
                    self.finishRecording()
                }
            }

            if let error {
                AppLogger.shared.error("Speech recognition error: \(error.localizedDescription)", category: "speech")
                self.state = .error(error.localizedDescription)
                self.finishRecording()
            }
        }

        state = .recording
        AppLogger.shared.info("Speech recording started", category: "speech")
        return stream
    }

    func stopRecording() {
        recognitionRequest?.endAudio()
        finishRecording()
    }

    // MARK: - Private

    private func finishRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        streamContinuation?.finish()
        streamContinuation = nil

        audioLevel = 0.0
        if case .error = state {
            // Keep error state
        } else {
            state = .idle
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func updateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        var sum: Float = 0
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }
        let average = sum / Float(frameLength)
        // Normalize to 0.0–1.0 range with some amplification
        let normalized = min(average * 5.0, 1.0)
        audioLevel = normalized
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension AppleSpeechProvider: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available {
            AppLogger.shared.warning("Speech recognition became unavailable", category: "speech")
            stopRecording()
        }
    }
}

// MARK: - Errors

enum SpeechError: LocalizedError {
    case unavailable
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .unavailable: "Speech recognition is not available on this device"
        case .notAuthorized: "Speech recognition or microphone access not authorized"
        }
    }
}

#else
// macOS stub — voice input is iOS-only
final class AppleSpeechProvider: SpeechRecognitionProvider {
    var state: SpeechRecognitionState { .error("Not available on macOS") }
    var isAvailable: Bool { false }
    var isAuthorized: Bool { false }
    var audioLevel: Float { 0.0 }

    func requestAuthorization() async -> Bool { false }
    func startRecording() throws -> AsyncStream<String> {
        AsyncStream { $0.finish() }
    }
    func stopRecording() {}
}

enum SpeechError: LocalizedError {
    case unavailable
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .unavailable: "Speech recognition is not available"
        case .notAuthorized: "Not authorized"
        }
    }
}
#endif
