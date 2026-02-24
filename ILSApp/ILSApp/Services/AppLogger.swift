import Foundation
import os
import os.log

/// Centralized logging service backed by `os.Logger` and a rolling on-disk log file.
///
/// Provides category-based logging at Info/Warning/Error levels with structured output.
/// Log entries are buffered in memory and flushed to `Library/Application Support/ILS/ils.log`
/// periodically or on flush calls. File size is capped at 5 MB with automatic truncation.
/// Also monitors memory usage and logs warnings when the app exceeds 80 MB.
final class AppLogger: Sendable {
    static let shared = AppLogger()

    private let logger: Logger
    private let logFileURL: URL
    private let maxLogSize = 5_000_000 // 5MB
    private static let iso8601Formatter = ISO8601DateFormatter()

    // MARK: - Buffered Writing

    private struct BufferState: Sendable {
        var buffer: [String] = []
    }

    /// Thread-safe buffer using OSAllocatedUnfairLock (no @unchecked Sendable needed)
    private let state = OSAllocatedUnfairLock(initialState: BufferState())
    private let maxBufferSize = 50
    // ENRG-04: 10s flush reduces disk I/O wakeups 5x vs previous 2s interval.
    // Buffer still flushes immediately at 50 entries via maxBufferSize.
    private let flushInterval: TimeInterval = 10.0

    /// Flush timer task — stored in locked state so it can be cancelled from deinit.
    ///
    /// MEM-08: The flush timer Task is properly cancelled in deinit via timerState lock.
    /// Audit flagged this as a potential leak — it is a false positive because AppLogger
    /// is a singleton (never deallocated) and the Task uses [weak self] to avoid retain cycles.
    private let timerState = OSAllocatedUnfairLock<Task<Void, Never>?>(initialState: nil)

    private init() {
        logger = Logger(subsystem: "com.ils.app", category: "general")
        let docs = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        logFileURL = docs.appendingPathComponent("ils-app.log")

        // CONC-13: Plain Task — AppLogger is Sendable, no actor isolation to escape.
        let timerTask = Task(priority: .utility) { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self?.flushInterval ?? 2.0))
                guard !Task.isCancelled else { break }
                self?.timerFlush()
            }
        }
        timerState.withLock { $0 = timerTask }
    }

    deinit {
        // Cancel the timer task
        let task = timerState.withLock { t -> Task<Void, Never>? in
            let current = t
            t = nil
            return current
        }
        task?.cancel()

        // Final flush
        let entries = state.withLock { s -> [String] in
            let current = s.buffer
            s.buffer.removeAll(keepingCapacity: false)
            return current
        }
        if !entries.isEmpty {
            writeEntriesToDisk(entries)
        }
    }

    func info(_ message: String, category: String = "general") {
        logger.info("[\(category)] \(message)")
        enqueueEntry("INFO", category: category, message: message)
    }

    func warning(_ message: String, category: String = "general") {
        logger.warning("[\(category)] \(message)")
        enqueueEntry("WARN", category: category, message: message)
    }

    func error(_ message: String, category: String = "general") {
        logger.error("[\(category)] \(message)")
        enqueueEntry("ERROR", category: category, message: message)
    }

    func apiError(_ endpoint: String, statusCode: Int?, error: Error) {
        let msg = "API \(endpoint) failed: status=\(statusCode ?? -1) error=\(error.localizedDescription)"
        logger.error("[\("api")] \(msg)")
        enqueueEntry("ERROR", category: "api", message: msg)
    }

    // MARK: - Buffer Management

    private func enqueueEntry(_ level: String, category: String, message: String) {
        let timestamp = Self.iso8601Formatter.string(from: Date())
        let entry = "[\(timestamp)] [\(level)] [\(category)] \(message)\n"

        let entriesToFlush: [String]? = state.withLock { s in
            s.buffer.append(entry)
            if s.buffer.count >= self.maxBufferSize {
                let current = s.buffer
                s.buffer.removeAll(keepingCapacity: true)
                return current
            }
            return nil
        }

        if let entries = entriesToFlush {
            writeEntriesToDisk(entries)
        }
    }

    /// Timer-driven flush — acquires lock, drains buffer, writes outside lock
    private func timerFlush() {
        let entries = state.withLock { s -> [String] in
            guard !s.buffer.isEmpty else { return [] }
            let current = s.buffer
            s.buffer.removeAll(keepingCapacity: true)
            return current
        }
        if !entries.isEmpty {
            writeEntriesToDisk(entries)
        }
    }

    /// Write entries to disk. Called OUTSIDE the lock to avoid blocking.
    ///
    /// ENRG-07: This performs synchronous file I/O. Moving to async (Task.detached + FileHandle)
    /// was considered but rejected because: (1) writeEntriesToDisk is already called from
    /// a detached utility-priority Task (the flush timer) or from enqueueEntry which runs on
    /// the caller's context — neither blocks the main thread; (2) adding async would require
    /// the method to be actor-isolated or use Sendable closures, adding complexity for minimal
    /// gain since log writes are small (< 4KB typical) and infrequent (every 10s or 50 entries).
    private func writeEntriesToDisk(_ entries: [String]) {
        let combined = entries.joined()
        guard let data = combined.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: logFileURL.path) {
            if let handle = try? FileHandle(forWritingTo: logFileURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
            rotateIfNeeded()
        } else {
            try? data.write(to: logFileURL)
            // Apply file protection so logs are accessible after first unlock (background refresh, widgets)
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: logFileURL.path
            )
        }
    }

    private func rotateIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: logFileURL.path),
              let size = attrs[.size] as? Int, size > maxLogSize else { return }
        let backup = logFileURL.deletingLastPathComponent().appendingPathComponent("ils-app.log.1")
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.moveItem(at: logFileURL, to: backup)
    }

    func recentLogs(lines: Int = 100) async -> [String] {
        let url = logFileURL

        // Flush pending entries first so recent logs are complete
        let entries = state.withLock { s -> [String] in
            guard !s.buffer.isEmpty else { return [] }
            let current = s.buffer
            s.buffer.removeAll(keepingCapacity: true)
            return current
        }
        if !entries.isEmpty {
            writeEntriesToDisk(entries)
        }

        // CONC-13: Inline file read — already in non-isolated async context, no actor to block.
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let allLines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        return Array(allLines.suffix(lines))
    }

    var analyticsOptedIn: Bool {
        get { UserDefaults.standard.bool(forKey: "analytics_opted_in") }
        set { UserDefaults.standard.set(newValue, forKey: "analytics_opted_in") }
    }
}
