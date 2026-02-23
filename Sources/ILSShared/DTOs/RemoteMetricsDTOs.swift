import Foundation

// MARK: - Remote Process with Highlighting

/// Information about a running system process, optionally annotated with a highlight type.
///
/// Used by the remote metrics API to surface process-level CPU and memory data
/// to the ILS client. Processes that are of particular interest (Claude, ILS
/// backend, Swift toolchain) are tagged with a ``ProcessHighlightType`` so the
/// UI can apply visual emphasis.
public struct RemoteProcessInfo: Codable, Sendable, Identifiable {
    /// The process identifier (PID) on the host system.
    public let pid: Int
    /// Human-readable process name (e.g. `"claude"`, `"node"`).
    public let name: String
    /// CPU utilisation as a percentage (0–100, may exceed 100 on multi-core hosts).
    public let cpuPercent: Double
    /// Resident memory consumed by the process, in megabytes.
    public let memoryMB: Double
    /// Full command-line string that launched the process, if available.
    public let command: String?
    /// Optional visual highlight category for this process.
    public let highlightType: ProcessHighlightType?

    /// Stable identifier — the process PID.
    public var id: Int { pid }

    /// Categories used to visually distinguish notable processes in the UI.
    public enum ProcessHighlightType: String, Codable, Sendable {
        /// The Claude Code CLI process.
        case claude
        /// The ILS backend server process.
        case ilsBackend = "ils_backend"
        /// A Swift compiler or toolchain process.
        case swift
        /// No special highlighting; treat as a regular process.
        case none

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            guard let value = Self(rawValue: raw) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Unrecognized ProcessHighlightType: '\(raw)'. Expected: claude, ils_backend, swift, none"
                    )
                )
            }
            self = value
        }
    }

    /// Creates a new ``RemoteProcessInfo``.
    /// - Parameters:
    ///   - pid: The system process identifier.
    ///   - name: Human-readable process name.
    ///   - cpuPercent: CPU utilisation percentage.
    ///   - memoryMB: Resident memory usage in megabytes.
    ///   - command: Full command-line string, if available.
    ///   - highlightType: Optional highlight category for UI emphasis.
    public init(
        pid: Int,
        name: String,
        cpuPercent: Double,
        memoryMB: Double,
        command: String? = nil,
        highlightType: ProcessHighlightType? = nil
    ) {
        self.pid = pid
        self.name = name
        self.cpuPercent = cpuPercent
        self.memoryMB = memoryMB
        self.command = command
        self.highlightType = highlightType
    }
}

// MARK: - Metrics Source Indicator

/// Indicates where system metrics were collected from.
///
/// When the ILS backend proxies metrics through a tunnel or remote host the
/// client needs to know whether it is seeing local or remote data, and which
/// host provided the readings.
public struct MetricsSourceResponse: Codable, Sendable {
    /// The origin of the metrics data.
    public let source: MetricsSource
    /// Display name of the host that supplied the metrics, if remote.
    public let hostName: String?

    /// Describes whether metrics originate from the local machine or a remote host.
    public enum MetricsSource: String, Codable, Sendable {
        /// Metrics were collected from the local machine running the ILS backend.
        case local
        /// Metrics were collected from a remote host via tunnel or proxy.
        case remote

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            guard let value = Self(rawValue: raw) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Unrecognized MetricsSource: '\(raw)'. Expected: local, remote"
                    )
                )
            }
            self = value
        }
    }

    /// Creates a new ``MetricsSourceResponse``.
    /// - Parameters:
    ///   - source: Origin of the metrics (local or remote).
    ///   - hostName: Optional display name of the remote host.
    public init(source: MetricsSource, hostName: String? = nil) {
        self.source = source
        self.hostName = hostName
    }
}
