import Foundation
import Observation
import SwiftUI
import ILSShared

/// ViewModel for the embedded terminal view.
///
/// Manages command input, ANSI-parsed output lines, command history (UserDefaults-backed,
/// max 200 entries), working directory tracking, and shell configuration.
@MainActor
@Observable
final class TerminalViewModel: BaseViewModel {

    // MARK: - Published State

    /// Current text in the command input field.
    var commandInput: String = ""

    /// Parsed terminal output lines ready for SwiftUI rendering.
    var outputLines: [AttributedString] = []

    /// Whether a command is currently executing.
    var isRunning: Bool = false

    /// Flat list of previously executed commands, newest last.
    var commandHistory: [String] = []

    /// Index into `commandHistory` for up/down navigation.
    /// -1 means no history item is selected (showing current input).
    var historyIndex: Int = -1

    /// Working directory reported by the last command execution.
    var currentDirectory: String = "~"

    /// Active terminal configuration (shell, environment, etc.).
    var shellConfig: TerminalConfig = TerminalConfig()

    // MARK: - Private State

    /// Saved draft of the command input before history navigation began.
    @ObservationIgnored private var inputDraft: String = ""

    // MARK: - Constants

    private static let historyUserDefaultsKey = "terminalCommandHistory"
    private static let maxHistoryEntries = 200

    // MARK: - Lifecycle

    override init() {
        super.init()
        loadHistory()
    }

    // MARK: - BaseViewModel Override

    override func configure(client: APIClient) {
        super.configure(client: client)
    }

    // MARK: - Command Execution

    /// Execute the current `commandInput` against the backend terminal API.
    ///
    /// Appends a prompt echo line, posts to `/api/v1/terminal/execute`, and appends
    /// parsed stdout/stderr to `outputLines`. On exit code != 0, stderr is shown in
    /// a dimmed style. Updates `currentDirectory` from the response.
    func executeCommand() async {
        let command = commandInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return }
        guard let apiClient = client else { return }

        // Echo the command to the output buffer
        appendPromptLine(command)

        // Update history before clearing input
        addToHistory(command)

        // Reset input and history cursor
        commandInput = ""
        historyIndex = -1
        inputDraft = ""

        isRunning = true
        defer { isRunning = false }

        let request = TerminalExecuteRequest(
            command: command,
            workingDirectory: currentDirectory == "~" ? nil : currentDirectory,
            timeout: nil,
            environment: shellConfig.environment.isEmpty ? nil : shellConfig.environment
        )

        do {
            let response: TerminalExecuteResponse = try await apiClient.post(
                "/terminal/execute",
                body: request
            )

            // Update working directory from response
            currentDirectory = response.workingDirectory

            // Append stdout (ANSI-parsed)
            if !response.stdout.isEmpty {
                let parsed = ANSIParser.parse(response.stdout)
                outputLines.append(parsed)
            }

            // Append stderr with a dimmed/error prefix
            if !response.stderr.isEmpty {
                var stderrString = AttributedString(response.stderr)
                stderrString.foregroundColor = .red
                stderrString.font = .system(.body, design: .monospaced)
                outputLines.append(stderrString)
            }

            // Show non-zero exit code hint
            if response.exitCode != 0 {
                var exitLine = AttributedString("exit \(response.exitCode)")
                exitLine.foregroundColor = .secondary
                exitLine.font = .system(.footnote, design: .monospaced)
                outputLines.append(exitLine)
            }

        } catch {
            self.error = error
            var errorLine = AttributedString("error: \(error.localizedDescription)")
            errorLine.foregroundColor = .red
            errorLine.font = .system(.body, design: .monospaced)
            outputLines.append(errorLine)
        }
    }

    // MARK: - Output Management

    /// Clear all output lines from the terminal.
    func clearOutput() {
        outputLines.removeAll()
    }

    // MARK: - History Navigation

    /// Navigate the command history.
    /// - Parameter direction: `.up` moves toward older entries; `.down` toward newer.
    func navigateHistory(_ direction: HistoryDirection) {
        guard !commandHistory.isEmpty else { return }

        switch direction {
        case .up:
            // Save current input as draft before first navigation
            if historyIndex == -1 {
                inputDraft = commandInput
            }
            let newIndex = historyIndex + 1
            if newIndex < commandHistory.count {
                historyIndex = newIndex
                // commandHistory is newest-last; index 0 = most recent
                commandInput = commandHistory[commandHistory.count - 1 - historyIndex]
            }

        case .down:
            if historyIndex <= 0 {
                // Back to the draft
                historyIndex = -1
                commandInput = inputDraft
            } else {
                historyIndex -= 1
                commandInput = commandHistory[commandHistory.count - 1 - historyIndex]
            }
        }
    }

    /// Direction for history navigation.
    enum HistoryDirection {
        case up
        case down
    }

    // MARK: - Persistence

    /// Load command history from UserDefaults.
    func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: Self.historyUserDefaultsKey),
              let decoded = try? JSONDecoder().decode([String].self, from: data)
        else { return }
        commandHistory = decoded
    }

    /// Persist command history to UserDefaults.
    func saveHistory() {
        guard let data = try? JSONEncoder().encode(commandHistory) else { return }
        UserDefaults.standard.set(data, forKey: Self.historyUserDefaultsKey)
    }

    // MARK: - Private Helpers

    /// Add a command to history, enforcing the 200-entry cap, and persist.
    private func addToHistory(_ command: String) {
        // Avoid consecutive duplicate entries
        if commandHistory.last != command {
            commandHistory.append(command)
        }

        // Trim to max
        if commandHistory.count > Self.maxHistoryEntries {
            commandHistory.removeFirst(commandHistory.count - Self.maxHistoryEntries)
        }

        saveHistory()
    }

    /// Append a prompt echo line to the output buffer.
    private func appendPromptLine(_ command: String) {
        let promptSymbol = "$ "
        var prompt = AttributedString(promptSymbol + command)
        prompt.font = .system(.body, design: .monospaced)
        // Style the prompt symbol distinctly
        if let promptRange = prompt.range(of: promptSymbol) {
            prompt[promptRange].foregroundColor = .green
        }
        outputLines.append(prompt)
    }
}
