import Foundation
import Observation
import ILSShared

/// Data point for time-series charts.
struct MetricDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
}

/// ViewModel for the System Monitor tab.
/// Owns the MetricsWebSocketClient and exposes chart data.
@MainActor
@Observable
final class SystemMetricsViewModel {
    var metricsClient: MetricsWebSocketClient
    var processes: [ProcessInfoResponse] = []
    var processSortBy: ProcessSortOption = .cpu
    var processSearchText: String = ""
    var isLoadingProcesses: Bool = false

    private let baseURL: String
    private let session: URLSession
    nonisolated private let decoder: JSONDecoder

    enum ProcessSortOption: String, CaseIterable {
        case cpu = "CPU"
        case memory = "Memory"
    }

    init(baseURL: String = "http://localhost:9999") {
        self.baseURL = baseURL
        self.metricsClient = MetricsWebSocketClient(baseURL: baseURL)
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: configuration)
        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Computed Properties

    var cpuPercentage: Double {
        metricsClient.latestMetrics?.cpu ?? 0
    }

    var memoryPercentage: Double {
        metricsClient.latestMetrics?.memory.percentage ?? 0
    }

    var memoryUsedGB: Double {
        Double(metricsClient.latestMetrics?.memory.used ?? 0) / 1_073_741_824
    }

    var memoryTotalGB: Double {
        Double(metricsClient.latestMetrics?.memory.total ?? 0) / 1_073_741_824
    }

    var diskPercentage: Double {
        metricsClient.latestMetrics?.disk.percentage ?? 0
    }

    var diskUsedGB: Double {
        Double(metricsClient.latestMetrics?.disk.used ?? 0) / 1_073_741_824
    }

    var diskTotalGB: Double {
        Double(metricsClient.latestMetrics?.disk.total ?? 0) / 1_073_741_824
    }

    var networkBytesIn: UInt64 {
        metricsClient.latestMetrics?.network.bytesIn ?? 0
    }

    var networkBytesOut: UInt64 {
        metricsClient.latestMetrics?.network.bytesOut ?? 0
    }

    var loadAverage: [Double] {
        metricsClient.latestMetrics?.loadAverage ?? []
    }

    var isConnected: Bool {
        metricsClient.isConnected
    }

    var filteredProcesses: [ProcessInfoResponse] {
        let sorted: [ProcessInfoResponse]
        switch processSortBy {
        case .cpu:
            sorted = processes.sorted { $0.cpuPercent > $1.cpuPercent }
        case .memory:
            sorted = processes.sorted { $0.memoryMB > $1.memoryMB }
        }

        if processSearchText.isEmpty {
            return sorted
        }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(processSearchText) }
    }

    // MARK: - Connection

    func connect() {
        metricsClient.connect()
    }

    func disconnect() {
        metricsClient.disconnect()
    }

    // MARK: - Process Loading

    func loadProcesses() async {
        isLoadingProcesses = true
        defer { isLoadingProcesses = false }

        let sortParam = processSortBy == .cpu ? "cpu" : "memory"
        guard let url = URL(string: "\(baseURL)/api/v1/system/processes?sort=\(sortParam)") else { return }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }
            processes = try decoder.decode([ProcessInfoResponse].self, from: data)
        } catch {
            // Silently fail - UI shows empty state
        }
    }
}
