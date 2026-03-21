import SwiftUI
import ILSShared

/// Format-picker sheet for exporting a session.
///
/// Presents a segmented `Picker` with JSON, Markdown, and PDF options, a format
/// description row, and an Export button that delegates to ``SessionInfoViewModel``
/// before presenting the system share sheet (``ShareSheet``), enabling AirDrop and
/// other iOS share destinations.
///
/// A new ``SessionInfoViewModel`` is created internally and configured with the
/// ``AppState`` API client in `.task`, mirroring the pattern used by
/// ``SessionCheckpointsView``.
///
/// ## Topics
/// ### Inputs
/// - ``session`` — the ``ChatSession`` to export
/// - ``messages`` — optional in-memory messages from the caller to avoid redundant API fetches
struct SessionExportPickerSheet: View {
    let session: ChatSession
    /// Pre-loaded messages from the caller (e.g. ``ChatView``). When provided, these are
    /// passed to the export pipeline to skip redundant API fetches and enable accurate
    /// range selection based on already-loaded messages.
    var messages: [ChatMessage]? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(AppState.self) var appState

    @State private var viewModel = SessionInfoViewModel()
    @State private var selectedFormat: ExportFormat = .markdown

    /// File URL written to `Caches/ShareExports/` for binary exports (JSON, PDF).
    @State private var exportedFileURL: URL?
    /// Filename passed to `ShareSheet(text:fileName:)` for Markdown exports.
    @State private var exportedFileName = ""
    @State private var showShareSheet = false

    /// Task handle for the current export, enabling cancellation.
    @State private var exportTask: Task<Void, Never>?

    // MARK: - Message Range Selection

    /// When `true`, export the full session. When `false`, use the selected range.
    @State private var exportFullSession = true
    /// 1-based start index for the message range.
    @State private var rangeStart: Int = 1
    /// 1-based end index for the message range.
    @State private var rangeEnd: Int = 1

    // MARK: - Computed

    private var sessionName: String {
        guard let name = session.name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "session"
        }
        return name
    }

    /// Total number of messages in the session (minimum 1 for UI purposes).
    /// Uses the count of pre-loaded messages when available, falling back to the session's `messageCount`.
    private var totalMessages: Int {
        max(messages?.count ?? session.messageCount, 1)
    }

    /// Number of messages in the selected range.
    private var selectedMessageCount: Int {
        exportFullSession ? totalMessages : max(rangeEnd - rangeStart + 1, 0)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section("Format") {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    formatDescriptionRow
                }

                if viewModel.isExporting {
                    Section("Export Progress") {
                        exportProgressRow
                    }
                }

                Section("Message Range") {
                    Toggle("Export full session", isOn: $exportFullSession)

                    if !exportFullSession {
                        Stepper(
                            "Start: message \(rangeStart)",
                            value: $rangeStart,
                            in: 1...max(rangeEnd, 1)
                        )

                        Stepper(
                            "End: message \(rangeEnd)",
                            value: $rangeEnd,
                            in: max(rangeStart, 1)...totalMessages
                        )
                    }

                    HStack {
                        Image(systemName: "number")
                            .foregroundStyle(theme.accent)
                        Text("\(selectedMessageCount) message\(selectedMessageCount == 1 ? "" : "s") selected")
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.bgPrimary)
            .navigationTitle("Export Session")
            #if os(iOS)
            .inlineNavigationBarTitle()
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isExporting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    exportButton
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportedFileURL {
                    ShareSheet(items: [url])
                } else {
                    ShareSheet(text: viewModel.exportMarkdown, fileName: exportedFileName)
                }
            }
            .alert("Export Failed", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .task {
                viewModel.configure(client: appState.apiClient)
                viewModel.preloadedMessages = messages
                rangeEnd = totalMessages
            }
            .interactiveDismissDisabled(viewModel.isExporting)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var formatDescriptionRow: some View {
        HStack(spacing: 12) {
            Image(systemName: selectedFormat.iconName)
                .font(.system(size: 20))
                .foregroundStyle(theme.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(selectedFormat.displayName)
                    .font(.body)
                    .foregroundStyle(theme.textPrimary)

                Text(selectedFormat.exportDescription)
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var exportProgressRow: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Exporting \(selectedFormat.displayName)…")
                    .font(.subheadline)
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Text("\(Int(viewModel.exportProgress * 100))%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(theme.textSecondary)
            }

            ProgressView(value: viewModel.exportProgress)
                .tint(theme.accent)

            Button(role: .destructive) {
                cancelExport()
            } label: {
                Label("Cancel Export", systemImage: "xmark.circle")
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var exportButton: some View {
        Button {
            exportTask = Task { await triggerExport() }
        } label: {
            if viewModel.isExporting {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text("Export")
                    .fontWeight(.semibold)
            }
        }
        .disabled(viewModel.isExporting)
    }

    // MARK: - Export Logic

    /// Cancels the in-flight export task and resets state.
    private func cancelExport() {
        exportTask?.cancel()
        exportTask = nil
        viewModel.isExporting = false
        viewModel.exportProgress = 0
    }

    /// Converts the 1-based UI range into a 0-based `ClosedRange<Int>` for the export pipeline.
    ///
    /// Returns `nil` when exporting the full session.
    private var exportRange: ClosedRange<Int>? {
        guard !exportFullSession else { return nil }
        let lower = max(rangeStart - 1, 0)
        let upper = max(rangeEnd - 1, lower)
        return lower...upper
    }

    private func triggerExport() async {
        exportedFileURL = nil
        let range = exportRange

        switch selectedFormat {
        case .markdown:
            exportedFileName = "\(sessionName).md"
            await viewModel.exportSession(session: session, range: range)
            guard viewModel.errorMessage == nil else { return }
            showShareSheet = true

        case .json:
            exportedFileName = "\(sessionName).json"
            await viewModel.exportJSON(session: session, range: range)
            guard viewModel.errorMessage == nil, let data = viewModel.exportData else { return }
            exportedFileURL = writeToShareExports(data: data, fileName: exportedFileName)
            guard exportedFileURL != nil else { return }
            showShareSheet = true

        case .pdf:
            exportedFileName = "\(sessionName).pdf"
            await viewModel.exportPDF(session: session, range: range)
            guard viewModel.errorMessage == nil, let data = viewModel.exportData else { return }
            exportedFileURL = writeToShareExports(data: data, fileName: exportedFileName)
            guard exportedFileURL != nil else { return }
            showShareSheet = true
        }
    }

    /// Writes `data` to `Caches/ShareExports/<fileName>` and returns the resulting URL.
    ///
    /// Returns `nil` and logs an error if the write fails.
    private func writeToShareExports(data: Data, fileName: String) -> URL? {
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ShareExports", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: cachesDir, withIntermediateDirectories: true)
            let fileURL = cachesDir.appendingPathComponent(fileName)
            try data.write(to: fileURL)
            return fileURL
        } catch {
            AppLogger.shared.error(
                "SessionExportPickerSheet file write failed: \(error.localizedDescription)",
                category: "export"
            )
            return nil
        }
    }
}

// MARK: - ExportFormat + UI Helpers

private extension ExportFormat {
    /// SF Symbol name used in the format description row.
    var iconName: String {
        switch self {
        case .json:     return "curlybraces"
        case .markdown: return "text.alignleft"
        case .pdf:      return "doc.richtext"
        }
    }

    /// One-line description shown beneath the format name in the picker sheet.
    var exportDescription: String {
        switch self {
        case .json:     return "Full conversation data and metadata in JSON format"
        case .markdown: return "Human-readable text with syntax-highlighted code blocks"
        case .pdf:      return "Formatted document for sharing with non-ILS users"
        }
    }
}
