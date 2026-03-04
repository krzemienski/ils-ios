import Foundation

struct HookExecutionEntry: Codable, Identifiable {
    let id: UUID
    var timestamp: Date
    var eventType: String
    var matcher: String?
    var hookType: String
    var actionSummary: String
    var exitCode: Int?
    var output: String?
    var durationMs: Int?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        eventType: String,
        matcher: String? = nil,
        hookType: String,
        actionSummary: String,
        exitCode: Int? = nil,
        output: String? = nil,
        durationMs: Int? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.matcher = matcher
        self.hookType = hookType
        self.actionSummary = actionSummary
        self.exitCode = exitCode
        self.output = output
        self.durationMs = durationMs
    }

    /// Whether the hook execution completed successfully (exit code 0 or not set).
    var succeeded: Bool {
        guard let code = exitCode else { return true }
        return code == 0
    }
}
