import Fluent
import Vapor
import ILSShared

/// Fluent model for ProcessHistory - tracks lifecycle of processes with resource usage peaks.
///
/// Records when processes start/stop, their duration, and peak resource consumption.
/// Used for audit trails, analysis, and debugging process behavior in multi-agent environments.
final class ProcessHistory: Model, Content, @unchecked Sendable {
    static let schema = "process_history"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "pid")
    var pid: Int

    @Field(key: "name")
    var name: String

    @OptionalField(key: "session_id")
    var sessionId: String?

    @Timestamp(key: "start_time", on: .create)
    var startTime: Date?

    @OptionalField(key: "end_time")
    var endTime: Date?

    @OptionalField(key: "duration")
    var duration: TimeInterval?

    @Field(key: "peak_cpu_percent")
    var peakCpuPercent: Double

    @Field(key: "peak_memory_mb")
    var peakMemoryMB: Double

    @OptionalField(key: "command")
    var command: String?

    init() {}

    init(
        id: UUID? = nil,
        pid: Int,
        name: String,
        sessionId: String? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        duration: TimeInterval? = nil,
        peakCpuPercent: Double = 0.0,
        peakMemoryMB: Double = 0.0,
        command: String? = nil
    ) {
        self.id = id
        self.pid = pid
        self.name = name
        self.sessionId = sessionId
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.peakCpuPercent = peakCpuPercent
        self.peakMemoryMB = peakMemoryMB
        self.command = command
    }

    /// Convert to shared ProcessHistoryResponse type
    func toResponse() -> ProcessHistoryResponse {
        ProcessHistoryResponse(
            id: id ?? UUID(),
            pid: pid,
            name: name,
            sessionId: sessionId,
            startTime: startTime ?? Date(),
            endTime: endTime,
            duration: duration,
            peakCpuPercent: peakCpuPercent,
            peakMemoryMB: peakMemoryMB,
            command: command
        )
    }

    /// Create from shared ProcessHistoryResponse type
    static func from(_ response: ProcessHistoryResponse) -> ProcessHistory {
        ProcessHistory(
            id: response.id,
            pid: response.pid,
            name: response.name,
            sessionId: response.sessionId,
            startTime: response.startTime,
            endTime: response.endTime,
            duration: response.duration,
            peakCpuPercent: response.peakCpuPercent,
            peakMemoryMB: response.peakMemoryMB,
            command: response.command
        )
    }
}
