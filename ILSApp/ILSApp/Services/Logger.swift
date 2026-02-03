import Foundation
import OSLog

/// Structured logging service for ILS app
/// Uses Apple's unified logging system (os.Logger) for performance and integration with system tools
final class Logger {
    static let shared = Logger()

    private let logger: os.Logger

    private init() {
        self.logger = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.ils.app", category: "ILSApp")
    }

    // MARK: - Logging Methods

    /// Log a debug message (for development only, not visible in production)
    func debug(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        let context = formatContext(file: file, line: line, function: function)
        logger.debug("\(context) \(message)")
    }

    /// Log an informational message
    func info(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        let context = formatContext(file: file, line: line, function: function)
        logger.info("\(context) \(message)")
    }

    /// Log a warning message
    func warning(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        let context = formatContext(file: file, line: line, function: function)
        logger.warning("\(context) \(message)")
    }

    /// Log an error message
    func error(_ message: String, error: Error? = nil, file: String = #file, line: Int = #line, function: String = #function) {
        let context = formatContext(file: file, line: line, function: function)
        if let error = error {
            logger.error("\(context) \(message) - Error: \(error.localizedDescription)")
        } else {
            logger.error("\(context) \(message)")
        }
    }

    // MARK: - Private Helpers

    private func formatContext(file: String, line: Int, function: String) -> String {
        let filename = (file as NSString).lastPathComponent
        return "[\(filename):\(line)] \(function)"
    }
}
