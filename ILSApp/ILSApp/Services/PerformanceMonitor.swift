#if canImport(UIKit)
import MetricKit

/// MetricKit subscriber that receives daily aggregated performance data and diagnostic payloads
/// from real user devices. Logs launch time histograms, peak memory, and crash/hang diagnostics
/// via AppLogger for production field monitoring.
final class PerformanceMonitor: NSObject, MXMetricManagerSubscriber {
    static let shared = PerformanceMonitor()

    private override init() {
        super.init()
    }

    /// Register as a MetricKit subscriber. Call after first frame (e.g., in `.task` modifier).
    func start() {
        MXMetricManager.shared.add(self)
        AppLogger.shared.info("MetricKit subscriber registered", category: "performance")
    }

    /// Unregister from MetricKit. Called on teardown if needed.
    func stop() {
        MXMetricManager.shared.remove(self)
        AppLogger.shared.info("MetricKit subscriber removed", category: "performance")
    }

    // MARK: - MXMetricManagerSubscriber

    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            if let launch = payload.applicationLaunchMetrics {
                AppLogger.shared.info(
                    "MetricKit launch: timeToFirstDraw=\(launch.histogrammedTimeToFirstDraw)",
                    category: "performance"
                )
            }

            if let memory = payload.memoryMetrics {
                AppLogger.shared.info(
                    "MetricKit memory: peak=\(memory.peakMemoryUsage)",
                    category: "performance"
                )
            }

            AppLogger.shared.info(
                "MetricKit payload: \(payload.jsonRepresentation())",
                category: "performance"
            )
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            AppLogger.shared.error(
                "MetricKit diagnostic: \(payload.jsonRepresentation())",
                category: "performance"
            )
        }
    }
}
#endif
