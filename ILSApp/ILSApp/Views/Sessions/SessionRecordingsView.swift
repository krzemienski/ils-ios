import SwiftUI
import ILSShared

/// Lists all recordings for a single session and manages their lifecycle.
///
/// Fetches recordings on appear via ``SessionRecordingViewModel/loadRecordings(sessionId:)``,
/// displaying each as a row with status badge, duration, and event count. A toolbar
/// Record button starts a new recording (with optional name), and a Stop button is
/// surfaced when a recording is active. Row swipe actions allow stopping an active
/// recording and deleting any recording. Tapping a row navigates to ``PlaybackView``
/// for time-lapse playback.
///
/// ## Topics
/// ### Inputs
/// - ``session`` - The session whose recordings are listed
///
/// ### State
/// - ``viewModel`` - Manages recording CRUD operations
struct SessionRecordingsView: View {
    let session: ChatSession

    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot

    @State private var viewModel = SessionRecordingViewModel()
    @State private var showStartSheet = false
    @State private var newRecordingName = ""
    @State private var recordingToDelete: SessionRecording?
    @State private var showDeleteAlert = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.recordings.isEmpty {
                loadingState
            } else if viewModel.recordings.isEmpty {
                emptyState
            } else {
                recordingsList
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle("Recordings")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                recordToolbarButton
            }
        }
        .alert("Delete Recording?", isPresented: $showDeleteAlert, presenting: recordingToDelete) { recording in
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteRecording(recordingId: recording.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { recording in
            Text("\"\(recording.sessionName ?? "Recording")\" will be permanently deleted and cannot be recovered.")
        }
        .sheet(isPresented: $showStartSheet) {
            startRecordingSheet
        }
        .task {
            viewModel.configure(client: appState.apiClient)
            await viewModel.loadRecordings(sessionId: session.id.uuidString)
        }
        .refreshable {
            await viewModel.loadRecordings(sessionId: session.id.uuidString)
        }
    }

    // MARK: - Recordings List

    @ViewBuilder
    private var recordingsList: some View {
        List {
            ForEach(viewModel.recordings) { recording in
                NavigationLink(destination: PlaybackView(recording: recording)) {
                    RecordingRow(recording: recording)
                }
                .listRowBackground(theme.bgSecondary)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        recordingToDelete = recording
                        showDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                    if recording.status == .recording {
                        Button {
                            HapticManager.impact(.medium)
                            Task { await viewModel.stopRecording(recordingId: recording.id) }
                        } label: {
                            Label("Stop", systemImage: "stop.circle")
                        }
                        .tint(theme.warning)
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .scrollContentBackground(.hidden)
    }

    // MARK: - Loading State

    @ViewBuilder
    private var loadingState: some View {
        VStack(spacing: theme.spacingMD) {
            ProgressView()
                .controlSize(.large)
            Text("Loading recordings…")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: theme.spacingMD) {
            Spacer()

            Image(systemName: "record.circle")
                .font(.system(size: 44, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            VStack(spacing: theme.spacingXS) {
                Text("No recordings yet")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Text("Tap Record to capture this session's progression as a time-lapse.")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, theme.spacingXL)
            }

            Button {
                HapticManager.impact(.light)
                showStartSheet = true
            } label: {
                Label("Start Recording", systemImage: "record.circle")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textOnAccent)
                    .padding(.horizontal, theme.spacingLG)
                    .padding(.vertical, theme.spacingSM)
                    .background(theme.error)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bgPrimary)
    }

    // MARK: - Toolbar Button

    @ViewBuilder
    private var recordToolbarButton: some View {
        if let active = viewModel.activeRecording {
            Button {
                HapticManager.impact(.medium)
                Task { await viewModel.stopRecording(recordingId: active.id) }
            } label: {
                HStack(spacing: 4) {
                    PulsingDot(color: theme.error)
                    Text("Stop")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                }
            }
            .foregroundStyle(theme.error)
            .accessibilityLabel("Stop active recording")
        } else {
            Button {
                HapticManager.impact(.light)
                showStartSheet = true
            } label: {
                Label("Record", systemImage: "record.circle")
                    .font(.system(size: theme.fontBody, weight: .medium))
            }
            .accessibilityLabel("Start a new recording")
        }
    }

    // MARK: - Start Recording Sheet

    @ViewBuilder
    private var startRecordingSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Recording name (optional)", text: $newRecordingName)
                        .autocorrectionDisabled()
                } header: {
                    Text("New Recording")
                } footer: {
                    Text("Leave blank to use an auto-generated name based on the session.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.bgPrimary)
            .navigationTitle("Start Recording")
            #if os(iOS)
            .inlineNavigationBarTitle()
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        let name = newRecordingName.isEmpty ? nil : newRecordingName
                        showStartSheet = false
                        newRecordingName = ""
                        Task {
                            await viewModel.startRecording(
                                sessionId: session.id.uuidString,
                                name: name
                            )
                        }
                    }
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showStartSheet = false
                        newRecordingName = ""
                    }
                }
            }
        }
        .environment(\.theme, theme)
        .presentationDetents([.medium])
    }
}

// MARK: - Recording Row

/// A single row in the recordings list.
///
/// Shows a status badge (pulsing red for active recording, green for ready/stopped,
/// gray for other), the recording name or fallback, duration, and event count.
private struct RecordingRow: View {
    let recording: SessionRecording

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        HStack(alignment: .center, spacing: theme.spacingSM) {
            statusBadge
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: theme.spacingXS) {
                    Text(displayName)
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Text(durationLabel)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }

                HStack(spacing: theme.spacingXS) {
                    statusLabel

                    Text("·")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)

                    Text("\(recording.eventCount) events")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)

                    if recording.keyMomentCount > 0 {
                        Text("·")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)

                        Label("\(recording.keyMomentCount) key", systemImage: "star.fill")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.warning)
                    }

                    Spacer()
                }
            }
        }
        .padding(.vertical, theme.spacingXS)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(displayName), \(statusAccessibilityLabel), \(durationLabel), \(recording.eventCount) events")
    }

    // MARK: - Status Badge

    @ViewBuilder
    private var statusBadge: some View {
        ZStack {
            switch recording.status {
            case .recording:
                Circle()
                    .fill(theme.error.opacity(0.15))
                PulsingDot(color: theme.error)
            case .ready, .stopped:
                Circle()
                    .fill(theme.success.opacity(0.15))
                Image(systemName: "play.fill")
                    .font(.system(size: theme.fontBody - 2, weight: .medium))
                    .foregroundStyle(theme.success)
            case .paused:
                Circle()
                    .fill(theme.warning.opacity(0.15))
                Image(systemName: "pause.fill")
                    .font(.system(size: theme.fontBody - 2, weight: .medium))
                    .foregroundStyle(theme.warning)
            case .processing:
                Circle()
                    .fill(theme.accent.opacity(0.15))
                ProgressView()
                    .controlSize(.small)
                    .tint(theme.accent)
            case .failed:
                Circle()
                    .fill(theme.error.opacity(0.15))
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: theme.fontBody - 2, weight: .medium))
                    .foregroundStyle(theme.error)
            }
        }
    }

    // MARK: - Status Label

    @ViewBuilder
    private var statusLabel: some View {
        Text(statusText)
            .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
            .foregroundStyle(statusColor)
    }

    // MARK: - Helpers

    private var displayName: String {
        recording.sessionName ?? "Recording \(shortId)"
    }

    private var shortId: String {
        String(recording.id.prefix(8))
    }

    private var durationLabel: String {
        guard let seconds = recording.durationSeconds, seconds > 0 else {
            return recording.status == .recording ? "Live" : "--:--"
        }
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return String(format: "%d:%02d:%02d", hours, mins, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    private var statusText: String {
        switch recording.status {
        case .recording:  return "Recording"
        case .paused:     return "Paused"
        case .stopped:    return "Stopped"
        case .processing: return "Processing"
        case .ready:      return "Ready"
        case .failed:     return "Failed"
        }
    }

    private var statusColor: Color {
        switch recording.status {
        case .recording:  return theme.error
        case .paused:     return theme.warning
        case .stopped:    return theme.textSecondary
        case .processing: return theme.accent
        case .ready:      return theme.success
        case .failed:     return theme.error
        }
    }

    private var statusAccessibilityLabel: String { statusText }
}

// MARK: - Pulsing Dot

/// An animated pulsing circle used to indicate an active recording.
private struct PulsingDot: View {
    let color: Color

    @State private var isPulsing = false
    @State private var isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var shouldAnimate: Bool {
        !reduceMotion && !isLowPowerMode && scenePhase == .active
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(isPulsing ? 0.0 : 0.3))
                .frame(width: 16, height: 16)
                .scaleEffect(isPulsing ? 1.5 : 1.0)
                .animation(
                    .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                    value: isPulsing
                )
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
        }
        .onAppear { startPulseIfNeeded() }
        .onDisappear { isPulsing = false }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                startPulseIfNeeded()
            } else {
                stopPulse()
            }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: Notification.Name.NSProcessInfoPowerStateDidChange
        )) { _ in
            isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
            if isLowPowerMode { stopPulse() }
        }
    }

    private func startPulseIfNeeded() {
        guard shouldAnimate else { return }
        isPulsing = true
    }

    private func stopPulse() {
        if reduceMotion || isLowPowerMode {
            isPulsing = false
        } else {
            withAnimation(.default) {
                isPulsing = false
            }
        }
    }
}
