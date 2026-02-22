import Foundation
import os.log

final class AppLogger: @unchecked Sendable {
    static let shared = AppLogger()

    private let logger: Logger
    private let logFileURL: URL
    private let maxLogSize: Int = 5_000_000 // 5MB
    private static let iso8601Formatter = ISO8601DateFormatter()

    // MARK: - Buffered Writing

    /// Internal buffer for log entries. Flushed periodically or when full.
    private var buffer: [String] = []
    private let bufferQueue = DispatchQueue(label: "com.ils.app.logger", qos: .utility)
    private let maxBufferSize = 50
    private let flushInterval: TimeInterval = 2.0
    private var flushTimer: DispatchSourceTimer?

    private init() {
        logger = Logger(subsystem: "com.ils.app", category: "general")
        let docs = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        logFileURL = docs.appendingPathComponent("ils-app.log")

        // Set up periodic flush timer
        let timer = DispatchSource.makeTimerSource(queue: bufferQueue)
        timer.schedule(deadline: .now() + flushInterval, repeating: flushInterval, leeway: .seconds(1))
        timer.setEventHandler { [weak self] in
            self?.flushBuffer()
        }
        timer.resume()
        flushTimer = timer
    }

    deinit {
        flushTimer?.cancel()
        // Final flush on deinit
        bufferQueue.sync { flushBuffer() }
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

        bufferQueue.async { [weak self] in
            guard let self else { return }
            self.buffer.append(entry)
            if self.buffer.count >= self.maxBufferSize {
                self.flushBuffer()
            }
        }
    }

    /// Flush buffered entries to disk. Called on bufferQueue.
    private func flushBuffer() {
        guard !buffer.isEmpty else { return }

        let entries = buffer
        buffer.removeAll(keepingCapacity: true)

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
        await withCheckedContinuation { continuation in
            bufferQueue.async { [weak self] in
                self?.flushBuffer()
                continuation.resume()
            }
        }
        return await Task.detached(priority: .userInitiated) {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [String]() }
            let allLines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
            return Array(allLines.suffix(lines))
        }.value
    }

    var analyticsOptedIn: Bool {
        get { UserDefaults.standard.bool(forKey: "analytics_opted_in") }
        set { UserDefaults.standard.set(newValue, forKey: "analytics_opted_in") }
    }
}
