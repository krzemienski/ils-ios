import Foundation

/// Crash reporting service for capturing and persisting app crashes
actor CrashReporter {
    static let shared = CrashReporter()

    private let fileManager = FileManager.default
    private var crashReportsDirectory: URL
    private var isConfigured = false

    private init() {
        // Create crash reports directory in app support
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        crashReportsDirectory = appSupport.appendingPathComponent("CrashReports", isDirectory: true)

        // Ensure directory exists
        try? fileManager.createDirectory(at: crashReportsDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Configuration

    /// Configure crash reporting handlers
    /// Must be called early in app lifecycle
    func configure() {
        guard !isConfigured else {
            Logger.shared.warning("CrashReporter already configured")
            return
        }

        Logger.shared.info("Configuring crash reporter")

        // Set up exception handler
        NSSetUncaughtExceptionHandler { exception in
            Task {
                await CrashReporter.shared.handleException(exception)
            }
        }

        // Set up signal handlers for common crash signals
        let signals = [SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGPIPE]
        for sig in signals {
            signal(sig) { signal in
                Task {
                    await CrashReporter.shared.handleSignal(signal)
                }
            }
        }

        isConfigured = true
        Logger.shared.info("Crash reporter configured successfully")
    }

    // MARK: - Crash Handling

    /// Handle uncaught exception
    private func handleException(_ exception: NSException) {
        Logger.shared.error("Uncaught exception: \(exception.name.rawValue) - \(exception.reason ?? "No reason")")

        let crashReport = CrashReport(
            timestamp: Date(),
            type: .exception,
            name: exception.name.rawValue,
            reason: exception.reason ?? "Unknown",
            callStack: exception.callStackSymbols,
            userInfo: exception.userInfo as? [String: String] ?? [:]
        )

        saveCrashReport(crashReport)
    }

    /// Handle Unix signal
    private func handleSignal(_ sig: Int32) {
        let signalName = signalToString(sig)
        Logger.shared.error("Fatal signal received: \(signalName)")

        let crashReport = CrashReport(
            timestamp: Date(),
            type: .signal,
            name: signalName,
            reason: "Fatal signal \(sig)",
            callStack: Thread.callStackSymbols,
            userInfo: [:]
        )

        saveCrashReport(crashReport)

        // Re-raise signal to allow system to handle it
        signal(sig, SIG_DFL)
        raise(sig)
    }

    // MARK: - Persistence

    /// Save crash report to disk
    private func saveCrashReport(_ report: CrashReport) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            let data = try encoder.encode(report)
            let filename = "crash_\(report.timestamp.timeIntervalSince1970).json"
            let fileURL = crashReportsDirectory.appendingPathComponent(filename)

            try data.write(to: fileURL)
            Logger.shared.info("Crash report saved: \(filename)")
        } catch {
            Logger.shared.error("Failed to save crash report", error: error)
        }
    }

    /// Get all pending crash reports
    func getPendingReports() -> [CrashReport] {
        do {
            let files = try fileManager.contentsOfDirectory(
                at: crashReportsDirectory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: .skipsHiddenFiles
            )

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            return files.compactMap { fileURL in
                guard fileURL.pathExtension == "json" else { return nil }

                do {
                    let data = try Data(contentsOf: fileURL)
                    return try decoder.decode(CrashReport.self, from: data)
                } catch {
                    Logger.shared.error("Failed to decode crash report: \(fileURL.lastPathComponent)", error: error)
                    return nil
                }
            }
        } catch {
            Logger.shared.error("Failed to read crash reports", error: error)
            return []
        }
    }

    /// Clear all pending crash reports
    func clearPendingReports() {
        do {
            let files = try fileManager.contentsOfDirectory(
                at: crashReportsDirectory,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )

            for fileURL in files where fileURL.pathExtension == "json" {
                try fileManager.removeItem(at: fileURL)
            }

            Logger.shared.info("Cleared \(files.count) crash reports")
        } catch {
            Logger.shared.error("Failed to clear crash reports", error: error)
        }
    }

    /// Check for and log any pending crash reports from previous session
    func checkForPreviousCrashes() {
        let reports = getPendingReports()

        if reports.isEmpty {
            Logger.shared.info("No crash reports from previous session")
            return
        }

        Logger.shared.warning("Found \(reports.count) crash report(s) from previous session")

        for report in reports {
            Logger.shared.error("Previous crash: \(report.type.rawValue) - \(report.name): \(report.reason)")
        }
    }

    // MARK: - Helpers

    private func signalToString(_ signal: Int32) -> String {
        switch signal {
        case SIGABRT: return "SIGABRT"
        case SIGILL: return "SIGILL"
        case SIGSEGV: return "SIGSEGV"
        case SIGFPE: return "SIGFPE"
        case SIGBUS: return "SIGBUS"
        case SIGPIPE: return "SIGPIPE"
        default: return "SIGNAL(\(signal))"
        }
    }
}

// MARK: - Data Models

/// Crash report data structure
struct CrashReport: Codable {
    let timestamp: Date
    let type: CrashType
    let name: String
    let reason: String
    let callStack: [String]
    let userInfo: [String: String]

    enum CrashType: String, Codable {
        case exception
        case signal
    }
}
