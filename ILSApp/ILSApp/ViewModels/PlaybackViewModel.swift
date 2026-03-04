import Foundation
import Observation
import ILSShared

/// View model for controlling time-lapse playback of a session recording.
///
/// Loads the recording and its full ordered event list from the backend, then
/// manages playback state: advancing ``currentOffset`` via a background tick loop,
/// deriving ``visibleEvents`` and ``highlightedEvent`` from the current position, and
/// supporting seek, speed change, and key-moment navigation.
///
/// ## Topics
/// ### Properties
/// - ``playbackData`` - Recording metadata and ordered event list from the backend
/// - ``isLoading`` - Whether playback data is being fetched
/// - ``isPlaying`` - Whether the timeline is actively advancing
/// - ``currentOffset`` - Seconds elapsed from the recording start (timeline position)
/// - ``speed`` - Current playback speed multiplier (1×, 2×, 5×, 10×)
///
/// ### Computed
/// - ``visibleEvents`` - Events whose offset is ≤ ``currentOffset``
/// - ``highlightedEvent`` - The most recently reached event during playback
/// - ``totalDuration`` - Full recording length in seconds
/// - ``progress`` - Normalised playback progress in [0, 1]
///
/// ### Operations
/// - ``configure(client:)`` - Inject the API client
/// - ``loadPlayback(recordingId:)`` - Fetch recording + events from the backend
/// - ``play()`` - Start advancing the timeline
/// - ``pause()`` - Pause timeline advancement
/// - ``seek(to:)`` - Jump to a specific offset
/// - ``setSpeed(_:)`` - Change playback speed
/// - ``skipToNextKeyMoment()`` - Jump forward to the next key-moment event
/// - ``skipToPrevKeyMoment()`` - Jump backward to the previous key-moment event
@Observable
@MainActor
class PlaybackViewModel {

    // MARK: - Observable Properties

    /// Full playback data (recording metadata + chronologically ordered events).
    var playbackData: RecordingEventsResponse?

    /// Whether a network fetch is currently in progress.
    var isLoading = false

    /// Most recent fetch error, if any.
    var error: Error?

    /// Whether the player is actively advancing the timeline.
    var isPlaying = false

    /// Current playback position in seconds from the recording start.
    var currentOffset: TimeInterval = 0

    /// Active playback speed multiplier.
    var speed: PlaybackSpeed = .oneX

    // MARK: - Computed: Visible Events

    /// Events whose ``RecordingEvent/offsetSeconds`` is at or before ``currentOffset``.
    ///
    /// The view layer renders this list to show the session "unfolding" in real-time
    /// as playback advances.
    var visibleEvents: [RecordingEvent] {
        guard let events = playbackData?.events else { return [] }
        return events.filter { $0.offsetSeconds <= currentOffset }
    }

    /// The most recently "reached" event at the current playback position.
    ///
    /// Views can use this to auto-scroll the event list or apply a highlight border.
    var highlightedEvent: RecordingEvent? {
        visibleEvents.last
    }

    // MARK: - Computed: Duration & Progress

    /// Total recording duration in seconds.
    ///
    /// Prefers the value stored on the ``SessionRecording`` metadata; falls back to
    /// the maximum ``RecordingEvent/offsetSeconds`` across all events.
    var totalDuration: TimeInterval {
        if let d = playbackData?.recording.durationSeconds, d > 0 { return d }
        return playbackData?.events.map(\.offsetSeconds).max() ?? 0
    }

    /// Normalised playback progress in [0, 1].
    var progress: Double {
        let total = totalDuration
        guard total > 0 else { return 0 }
        return min(currentOffset / total, 1.0)
    }

    // MARK: - Private State

    private var client: APIClient?

    /// Background task driving the playback tick loop.
    nonisolated(unsafe) private var playbackTask: Task<Void, Never>?

    /// Interval (seconds) between successive timer ticks.
    private let tickInterval: TimeInterval = 0.1

    // MARK: - Lifecycle

    deinit {
        playbackTask?.cancel()
    }

    // MARK: - Configuration

    /// Inject the API client. Must be called before any data operations.
    func configure(client: APIClient) {
        self.client = client
    }

    // MARK: - Load Playback Data

    /// Fetch the recording and its full ordered event list from the backend.
    ///
    /// Resets the timeline to 0 and pauses any active playback before loading.
    ///
    /// - Parameter recordingId: UUID string of the recording to load.
    func loadPlayback(recordingId: String) async {
        guard let client else { return }
        pause()
        currentOffset = 0
        isLoading = true
        error = nil

        do {
            let response: APIResponse<RecordingEventsResponse> = try await client.get(
                "/recordings/\(recordingId)/events"
            )
            playbackData = response.data
        } catch {
            self.error = error
        }

        isLoading = false
    }

    // MARK: - Playback Controls

    /// Start advancing the timeline from the current ``currentOffset``.
    ///
    /// If the recording has already reached its end, restarts from offset 0.
    /// No-ops if already playing or no data is loaded.
    func play() {
        guard playbackData != nil, !isPlaying else { return }
        if totalDuration > 0, currentOffset >= totalDuration {
            currentOffset = 0
        }
        isPlaying = true
        startTickLoop()
    }

    /// Pause timeline advancement, preserving the current offset.
    func pause() {
        isPlaying = false
        playbackTask?.cancel()
        playbackTask = nil
    }

    /// Jump the timeline to the given offset, clamped to [0, totalDuration].
    ///
    /// Playback state (playing/paused) is preserved after seeking.
    ///
    /// - Parameter offset: Target position in seconds from the recording start.
    func seek(to offset: TimeInterval) {
        currentOffset = max(0, min(offset, totalDuration))
        if isPlaying {
            playbackTask?.cancel()
            playbackTask = nil
            startTickLoop()
        }
    }

    /// Change the playback speed.
    ///
    /// If the player is currently playing, the tick loop is restarted immediately
    /// so the new speed takes effect without waiting for the current tick.
    ///
    /// - Parameter newSpeed: One of the supported ``PlaybackSpeed`` multipliers.
    func setSpeed(_ newSpeed: PlaybackSpeed) {
        speed = newSpeed
        if isPlaying {
            playbackTask?.cancel()
            playbackTask = nil
            startTickLoop()
        }
    }

    /// Advance to the nearest key-moment event after the current offset.
    ///
    /// If no key moment exists beyond the current position, does nothing.
    func skipToNextKeyMoment() {
        guard let events = playbackData?.events else { return }
        if let next = events.first(where: { $0.isKeyMoment && $0.offsetSeconds > currentOffset }) {
            seek(to: next.offsetSeconds)
        }
    }

    /// Jump back to the nearest key-moment event before the current offset.
    ///
    /// Uses a 0.5-second look-behind threshold so repeated taps step backwards
    /// through key moments rather than staying at the current one.
    func skipToPrevKeyMoment() {
        guard let events = playbackData?.events else { return }
        let threshold = 0.5
        if let prev = events.last(where: { $0.isKeyMoment && $0.offsetSeconds < currentOffset - threshold }) {
            seek(to: prev.offsetSeconds)
        }
    }

    // MARK: - Private: Tick Loop

    /// Starts a repeating async tick loop that advances ``currentOffset`` by
    /// `speed.rawValue × tickInterval` each iteration until playback stops or the
    /// recording reaches its end.
    private func startTickLoop() {
        let tickNanos = UInt64(tickInterval * 1_000_000_000)
        playbackTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: tickNanos)
                guard let self, !Task.isCancelled else { break }
                self.tick()
            }
        }
    }

    /// Single playback tick — advances the offset or stops at the recording end.
    private func tick() {
        guard isPlaying else { return }
        let advance = speed.rawValue * tickInterval
        let newOffset = currentOffset + advance
        let total = totalDuration
        if total > 0, newOffset >= total {
            currentOffset = total
            pause()
        } else {
            currentOffset = newOffset
        }
    }
}
