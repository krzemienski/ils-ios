import Foundation
import os.log

final class AppLogger {
    static let shared = AppLogger()

    private let logger: Logger
    private let logFileURL: URL
    private let maxLogSize: Int = 1_000_000 // 1MB
    private static let iso8601Formatter = ISO8601DateFormatter()

    /// Serial queue for all file I/O — avoids blocking the main thread
    private let writeQueue = DispatchQueue(label: "com.ils.app.logger.write", qos: .utility)

    /// Buffer for pending log entries, flushed at threshold or on timer
    private var buffer: [Data] = []
    private let bufferThreshold = 50
    private var flushTimer: DispatchSourceTimer?

    private init() {
        logger = Logger(subsystem: "com.ils.app", category: "general")
        let docs = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let logURL = docs.appendingPathComponent("ils-app.log")
        logFileURL = logURL
        // Mark log file as excluded from backup
        var mutableURL = logURL
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        do {
            try mutableURL.setResourceValues(values)
        } catch {
            logger.error("Failed to exclude log file from backup: \(error.localizedDescription)")
        }

        // Flush buffer every 30 seconds if entries are pending
        let timer = DispatchSource.makeTimerSource(queue: writeQueue)
        timer.schedule(deadline: .now() + 30, repeating: 30, leeway: .seconds(5))
        timer.setEventHandler { [weak self] in
            self?.flushBuffer()
        }
        timer.resume()
        flushTimer = timer
    }

    func info(_ message: String, category: String = "general") {
        logger.info("[\(category)] \(message)")
        enqueueWrite("INFO", category: category, message: message)
    }

    func warning(_ message: String, category: String = "general") {
        logger.warning("[\(category)] \(message)")
        enqueueWrite("WARN", category: category, message: message)
    }

    func error(_ message: String, category: String = "general") {
        logger.error("[\(category)] \(message)")
        enqueueWrite("ERROR", category: category, message: message)
    }

    func apiError(_ endpoint: String, statusCode: Int?, error: Error) {
        let msg = "API \(endpoint) failed: status=\(statusCode ?? -1) error=\(error.localizedDescription)"
        logger.error("[\("api")] \(msg)")
        enqueueWrite("ERROR", category: "api", message: msg)
    }

    /// Enqueue a log entry into the buffer, flush when threshold is reached
    private func enqueueWrite(_ level: String, category: String, message: String) {
        let now = Date()
        writeQueue.async { [weak self] in
            guard let self else { return }
            let timestamp = Self.iso8601Formatter.string(from: now)
            let entry = "[\(timestamp)] [\(level)] [\(category)] \(message)\n"
            guard let data = entry.data(using: .utf8) else { return }
            self.buffer.append(data)
            if self.buffer.count >= self.bufferThreshold {
                self.flushBuffer()
            }
        }
    }

    /// Flush all buffered entries to disk (called on writeQueue)
    private func flushBuffer() {
        guard !buffer.isEmpty else { return }
        let entriesToWrite = buffer
        buffer.removeAll(keepingCapacity: true)

        let totalSize = entriesToWrite.reduce(0) { $0 + $1.count }
        var combined = Data()
        combined.reserveCapacity(totalSize)
        for entry in entriesToWrite {
            combined.append(entry)
        }

        if FileManager.default.fileExists(atPath: logFileURL.path) {
            if let handle = try? FileHandle(forWritingTo: logFileURL) {
                handle.seekToEndOfFile()
                handle.write(combined)
                handle.closeFile()
            }
            rotateIfNeeded()
        } else {
            try? combined.write(to: logFileURL)
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
        return await Task.detached(priority: .userInitiated) {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [String]() }
            let allLines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
            return Array(allLines.suffix(lines))
        }.value
    }

    var analyticsOptedIn: Bool {
        get { UserDefaults.standard.bool(forKey: AppConstants.analyticsOptedInKey) }
        set { UserDefaults.standard.set(newValue, forKey: AppConstants.analyticsOptedInKey) }
    }
}
