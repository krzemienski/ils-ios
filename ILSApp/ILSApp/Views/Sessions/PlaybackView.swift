import SwiftUI
import ILSShared

/// Time-lapse playback view for a session recording.
///
/// Loads the full event list for a recording, then lets the user scrub through
/// and replay the session in real-time (or at 2×/5×/10× speed). As the playhead
/// advances, events are progressively revealed in a scrolling list that
/// auto-scrolls to the current event. Key moments (errors, permissions,
/// completions) are marked with a coloured leading stripe and star badge.
///
/// An Export toolbar button opens an options sheet (format + redact toggle),
/// performs the export, and then presents a standard system share sheet.
///
/// ## Topics
/// ### Inputs
/// - ``recording`` - Metadata for the recording to play
///
/// ### Playback Controls
/// - Timeline slider bound to ``PlaybackViewModel/currentOffset``
/// - Speed picker cycling through ``PlaybackSpeed`` cases (1×, 2×, 5×, 10×)
/// - Play / pause toggle
/// - Previous / next key-moment skip buttons
///
/// ### Event List
/// - Scrolling ``PlaybackEventRow`` list, auto-scrolling to
///   ``PlaybackViewModel/highlightedEvent`` during playback
/// - Key-moment rows highlighted with a coloured leading stripe
///
/// ### Export
/// - Toolbar button opens export-options sheet; on success presents ShareLink
struct PlaybackView: View {
    let recording: SessionRecording

    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot

    @State private var viewModel = PlaybackViewModel()

    // Export state
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showExportOptions = false
    @State private var exportFormat = "json"
    @State private var redactContent = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.playbackData == nil {
                loadingState
            } else if let error = viewModel.error, viewModel.playbackData == nil {
                errorState(error)
            } else {
                playbackContent
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle(recording.sessionName ?? "Playback")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                toolbarExportButton
            }
        }
        .sheet(isPresented: $showExportOptions) {
            exportOptionsSheet
                .environment(\.theme, theme)
        }
        .task {
            viewModel.configure(client: appState.apiClient)
            await viewModel.loadPlayback(recordingId: recording.id)
        }
        .onDisappear {
            viewModel.pause()
        }
    }

    // MARK: - Playback Content

    @ViewBuilder
    private var playbackContent: some View {
        VStack(spacing: 0) {
            controlsPanel
                .padding(theme.spacingMD)
                .background(theme.bgSecondary)

            Divider()
                .overlay(theme.divider)

            eventsList
        }
    }

    // MARK: - Controls Panel

    @ViewBuilder
    private var controlsPanel: some View {
        VStack(spacing: theme.spacingSM) {
            timelineSlider
            playbackControlRow
        }
    }

    @ViewBuilder
    private var timelineSlider: some View {
        let total = viewModel.totalDuration
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { viewModel.currentOffset },
                    set: { viewModel.seek(to: $0) }
                ),
                in: 0...max(total, 1)
            )
            .tint(theme.accent)
            .accessibilityLabel("Playback position")
            .accessibilityValue(timeLabel(viewModel.currentOffset))

            HStack {
                Text(timeLabel(viewModel.currentOffset))
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign).monospacedDigit())
                    .foregroundStyle(theme.textSecondary)
                    .frame(minWidth: 40, alignment: .leading)

                Spacer()

                if let data = viewModel.playbackData {
                    Text("\(viewModel.visibleEvents.count) / \(data.events.count) events")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }

                Spacer()

                Text(timeLabel(total))
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign).monospacedDigit())
                    .foregroundStyle(theme.textTertiary)
                    .frame(minWidth: 40, alignment: .trailing)
            }
        }
    }

    @ViewBuilder
    private var playbackControlRow: some View {
        HStack(spacing: theme.spacingMD) {
            // Previous key moment
            Button {
                HapticManager.impact(.light)
                viewModel.skipToPrevKeyMoment()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: theme.fontBody, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
            }
            .accessibilityLabel("Previous key moment")
            .disabled(viewModel.playbackData == nil)

            // Play / Pause
            Button {
                HapticManager.impact(.medium)
                if viewModel.isPlaying {
                    viewModel.pause()
                } else {
                    viewModel.play()
                }
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(viewModel.playbackData != nil ? theme.accent : theme.textTertiary)
            }
            .accessibilityLabel(viewModel.isPlaying ? "Pause playback" : "Start playback")
            .disabled(viewModel.playbackData == nil)

            // Next key moment
            Button {
                HapticManager.impact(.light)
                viewModel.skipToNextKeyMoment()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: theme.fontBody, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
            }
            .accessibilityLabel("Next key moment")
            .disabled(viewModel.playbackData == nil)

            Spacer()

            // Speed picker
            Picker("Speed", selection: Binding(
                get: { viewModel.speed },
                set: { viewModel.setSpeed($0) }
            )) {
                ForEach(PlaybackSpeed.allCases, id: \.self) { speed in
                    Text(speed.label).tag(speed)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 160)
            .accessibilityLabel("Playback speed")
        }
    }

    // MARK: - Events List

    @ViewBuilder
    private var eventsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if viewModel.playbackData == nil {
                        noDataState
                    } else if viewModel.visibleEvents.isEmpty {
                        waitingToPlayState
                    } else {
                        ForEach(viewModel.visibleEvents) { event in
                            PlaybackEventRow(
                                event: event,
                                isHighlighted: event.id == viewModel.highlightedEvent?.id
                            )
                            .id(event.id)
                            .padding(.horizontal, theme.spacingXS)

                            Divider()
                                .overlay(theme.divider)
                                .padding(.leading, theme.spacingMD + 34 + theme.spacingSM)
                        }
                    }
                }
                .padding(.vertical, theme.spacingXS)
            }
            .background(theme.bgPrimary)
            .onChange(of: viewModel.highlightedEvent?.id) { _, newId in
                if let id = newId {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var noDataState: some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "film")
                .font(.system(size: 44, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
            Text("No events in this recording")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
            Text("This recording captured no events to replay.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacingXL)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacingXL * 2)
    }

    @ViewBuilder
    private var waitingToPlayState: some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "play.circle")
                .font(.system(size: 44, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
            Text("Press play to begin")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            let keyCount = viewModel.playbackData?.recording.keyMomentCount ?? 0
            if keyCount > 0 {
                Label("\(keyCount) key moment\(keyCount == 1 ? "" : "s") highlighted", systemImage: "star.fill")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.warning)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacingXL * 2)
    }

    // MARK: - Export

    @ViewBuilder
    private var toolbarExportButton: some View {
        if isExporting {
            ProgressView()
                .controlSize(.small)
        } else if let url = exportURL {
            ShareLink(
                item: url,
                subject: Text(recording.sessionName ?? "Session Recording"),
                message: Text("Session recording export")
            ) {
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.system(size: theme.fontBody, weight: .medium))
                    .foregroundStyle(theme.accent)
            }
            .accessibilityLabel("Share exported recording")
        } else {
            Button {
                HapticManager.impact(.light)
                showExportOptions = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: theme.fontBody, weight: .medium))
            }
            .accessibilityLabel("Export recording")
        }
    }

    @ViewBuilder
    private var exportOptionsSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Format", selection: $exportFormat) {
                        Text("JSON").tag("json")
                        Text("Markdown").tag("markdown")
                    }
                    Toggle("Redact sensitive content", isOn: $redactContent)
                } header: {
                    Text("Export Options")
                } footer: {
                    Text("Redacting removes message content before exporting, keeping only event types and timestamps.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.bgPrimary)
            .navigationTitle("Export Recording")
            #if os(iOS)
            .inlineNavigationBarTitle()
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export") {
                        showExportOptions = false
                        Task { await performExport() }
                    }
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showExportOptions = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func performExport() async {
        isExporting = true
        defer { isExporting = false }

        do {
            let data = try await appState.apiClient.getRawData(
                "/recordings/\(recording.id)/export?format=\(exportFormat)&redact=\(redactContent)"
            )
            let ext = exportFormat == "markdown" ? "md" : "json"
            let safeName = (recording.sessionName ?? "recording")
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(safeName).\(ext)")
            try data.write(to: url)
            exportURL = url
        } catch {
            // Export error silently handled — toolbar button remains available for retry
        }
    }

    // MARK: - Loading State

    @ViewBuilder
    private var loadingState: some View {
        VStack(spacing: theme.spacingMD) {
            Spacer()
            ProgressView()
                .progressViewStyle(.circular)
                .tint(theme.textSecondary)
            Text("Loading recording…")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Error State

    @ViewBuilder
    private func errorState(_ error: Error) -> some View {
        VStack(spacing: theme.spacingMD) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44, design: theme.fontDesign))
                .foregroundStyle(theme.error)
            VStack(spacing: theme.spacingXS) {
                Text("Failed to load recording")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Text(error.localizedDescription)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, theme.spacingXL)
            }
            Button {
                HapticManager.impact(.medium)
                Task { await viewModel.loadPlayback(recordingId: recording.id) }
            } label: {
                Text("Retry")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textOnAccent)
                    .padding(.horizontal, theme.spacingLG)
                    .padding(.vertical, theme.spacingSM)
                    .background(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            }
            .accessibilityLabel("Retry loading recording")
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Time Formatting

    private func timeLabel(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let s = total % 60
        let m = (total / 60) % 60
        let h = total / 3600
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Playback Event Row

/// A single row in the time-lapse playback event list.
///
/// Renders an event-type icon badge, title, optional detail, and a
/// monospaced offset timestamp. Key-moment events receive a coloured
/// leading stripe and a star badge labelling the moment type.
/// The currently highlighted (most-recently-reached) event is given an
/// accent-tinted background and border to draw focus during playback.
private struct PlaybackEventRow: View {
    /// The event to render.
    let event: RecordingEvent
    /// Whether this is the most-recently-reached event in the playback timeline.
    let isHighlighted: Bool

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: theme.spacingSM) {
            // Key-moment stripe
            Rectangle()
                .fill(event.isKeyMoment ? keyMomentColor : Color.clear)
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 1.5))
                .padding(.vertical, 4)

            // Event-type icon badge
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: eventIcon)
                    .font(.system(size: theme.fontBody - 1, weight: .medium))
                    .foregroundStyle(iconColor)
            }

            // Content stack
            VStack(alignment: .leading, spacing: 3) {
                // Title + offset timestamp
                HStack(alignment: .firstTextBaseline, spacing: theme.spacingXS) {
                    Text(event.title)
                        .font(.system(
                            size: theme.fontBody,
                            weight: isHighlighted ? .semibold : .regular,
                            design: theme.fontDesign
                        ))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(2)

                    Spacer(minLength: theme.spacingXS)

                    Text(offsetLabel)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign).monospacedDigit())
                        .foregroundStyle(theme.textTertiary)
                        .layoutPriority(1)
                }

                // Optional detail
                if let detail = event.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }

                // Key-moment badge
                if event.isKeyMoment {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: theme.fontCaption - 2))
                            .foregroundStyle(keyMomentColor)
                        Text(keyMomentLabel)
                            .font(.system(size: theme.fontCaption - 1, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(keyMomentColor)
                    }
                }
            }
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, theme.spacingXS + 2)
        .background(isHighlighted ? theme.accent.opacity(0.08) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .stroke(isHighlighted ? theme.accent.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .animation(.easeInOut(duration: 0.2), value: isHighlighted)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Helpers

    private var offsetLabel: String {
        let total = max(0, Int(event.offsetSeconds))
        let s = total % 60
        let m = (total / 60) % 60
        let h = total / 3600
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    private var eventIcon: String {
        switch event.eventType {
        case .messageSent:        return "message.fill"
        case .messageReceived:    return "message.fill"
        case .fileChange:         return "doc.fill"
        case .permissionRequest:  return "exclamationmark.triangle.fill"
        case .permissionDecision: return "checkmark.shield.fill"
        case .error:              return "xmark.circle.fill"
        case .completion:         return "checkmark.circle.fill"
        case .sessionStart:       return "play.fill"
        case .sessionEnd:         return "stop.fill"
        case .systemEvent:        return "bolt.fill"
        }
    }

    private var iconColor: Color {
        switch event.eventType {
        case .messageSent:        return theme.accent
        case .messageReceived:    return theme.accent
        case .fileChange:         return theme.textSecondary
        case .permissionRequest:  return theme.warning
        case .permissionDecision: return theme.success
        case .error:              return theme.error
        case .completion:         return theme.success
        case .sessionStart:       return theme.success
        case .sessionEnd:         return theme.textSecondary
        case .systemEvent:        return theme.accent
        }
    }

    private var keyMomentColor: Color {
        switch event.eventType {
        case .error:             return theme.error
        case .permissionRequest: return theme.warning
        case .completion:        return theme.success
        default:                 return theme.warning
        }
    }

    private var keyMomentLabel: String {
        switch event.eventType {
        case .error:             return "Error"
        case .permissionRequest: return "Permission"
        case .completion:        return "Complete"
        default:                 return "Key Moment"
        }
    }

    private var accessibilityLabel: String {
        var parts = [event.title]
        if let detail = event.detail, !detail.isEmpty {
            parts.append(detail)
        }
        parts.append("at \(offsetLabel)")
        if event.isKeyMoment {
            parts.append(keyMomentLabel)
        }
        return parts.joined(separator: ", ")
    }
}
