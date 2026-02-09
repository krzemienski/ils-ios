import Foundation

// MARK: - Remote Process with Highlighting

public struct RemoteProcessInfo: Codable, Sendable, Identifiable {
    public let pid: Int
    public let name: String
    public let cpuPercent: Double
    public let memoryMB: Double
    public let command: String?
    public let highlightType: ProcessHighlightType?

    public var id: Int { pid }

    public enum ProcessHighlightType: String, Codable, Sendable {
        case claude
        case ilsBackend = "ils_backend"
        case swift
        case none
    }

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

public struct MetricsSourceResponse: Codable, Sendable {
    public let source: MetricsSource
    public let hostName: String?

    public enum MetricsSource: String, Codable, Sendable {
        case local
        case remote
    }

    public init(source: MetricsSource, hostName: String? = nil) {
        self.source = source
        self.hostName = hostName
    }
}
