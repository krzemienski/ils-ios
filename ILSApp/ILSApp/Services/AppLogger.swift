import Foundation
import os.log

final class AppLogger {
    static let shared = AppLogger()

    private let logger: Logger
    private let logFileURL: URL
    private let maxLogSize: Int = 5_000_000 // 5MB
    private static let iso8601Formatter = ISO8601DateFormatter()

    private init() {
        logger = Logger(subsystem: "com.ils.app", category: "general")
        let docs = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        logFileURL = docs.appendingPathComponent("ils-app.log")
    }

    func info(_ message: String, category: String = "general") {
        logger.info("[\(category)] \(message)")
        writeToFile("INFO", category: category, message: message)
    }

    func warning(_ message: String, category: String = "general") {
        logger.warning("[\(category)] \(message)")
        writeToFile("WARN", category: category, message: message)
    }

    func error(_ message: String, category: String = "general") {
        logger.error("[\(category)] \(message)")
        writeToFile("ERROR", category: category, message: message)
    }

    func apiError(_ endpoint: String, statusCode: Int?, error: Error) {
        let msg = "API \(endpoint) failed: status=\(statusCode ?? -1) error=\(error.localizedDescription)"
        logger.error("[\("api")] \(msg)")
        writeToFile("ERROR", category: "api", message: msg)
    }

    private func writeToFile(_ level: String, category: String, message: String) {
        let timestamp = Self.iso8601Formatter.string(from: Date())
        let entry = "[\(timestamp)] [\(level)] [\(category)] \(message)\n"

        guard let data = entry.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: logFileURL.path) {
            if let handle = try? FileHandle(forWritingTo: logFileURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
            rotateIfNeeded()
        } else {
            try? data.write(to: logFileURL)
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
        get { UserDefaults.standard.bool(forKey: "analytics_opted_in") }
        set { UserDefaults.standard.set(newValue, forKey: "analytics_opted_in") }
    }
}
