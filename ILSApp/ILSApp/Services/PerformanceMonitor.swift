#if canImport(UIKit)
// CONC-27: @preconcurrency suppresses Sendable warnings for MXMetricPayload and
// MXDiagnosticPayload which pre-date Swift 6 and lack Sendable conformance.
@preconcurrency import MetricKit

/// MetricKit subscriber that receives daily aggregated performance data and diagnostic payloads
/// from real user devices. Logs launch time histograms, peak memory, and crash/hang diagnostics
/// via AppLogger for production field monitoring.
///
/// CRIT-C1: @MainActor ensures state access is safe. MetricKit delivers didReceive callbacks
/// on an arbitrary background queue, so those methods are marked `nonisolated` with a
/// Task hop back to the main actor.
@MainActor
final class PerformanceMonitor: NSObject, MXMetricManagerSubscriber {
    static let shared = PerformanceMonitor()

    // MARK: - Crash-Free Session Tracking

    private enum Keys {
        static let sessionCount = "performance.sessionCount"
        static let crashCount = "performance.crashCount"
    }

    /// Total number of app sessions recorded since install.
    private(set) var sessionCount: Int {
        get { UserDefaults.standard.integer(forKey: Keys.sessionCount) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.sessionCount) }
    }

    /// Total number of crashes detected via MetricKit diagnostic payloads.
    private(set) var crashCount: Int {
        get { UserDefaults.standard.integer(forKey: Keys.crashCount) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.crashCount) }
    }

    /// Ratio of crash-free sessions: 1.0 means no crashes recorded.
    var crashFreeRate: Double {
        guard sessionCount > 0 else { return 1.0 }
        let crashedSessions = min(crashCount, sessionCount)
        return Double(sessionCount - crashedSessions) / Double(sessionCount)
    }

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

    /// Increment the session launch counter. Call once at app launch.
    func sessionStarted() {
        sessionCount += 1
        AppLogger.shared.info(
            "Session started — total: \(sessionCount), crashFreeRate: \(String(format: "%.3f", crashFreeRate))",
            category: "performance"
        )
    }

    // MARK: - MXMetricManagerSubscriber

    /// MetricKit delivers on arbitrary background queue — `nonisolated` with actor hop.
    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        // CONC-27: MXMetricPayload is non-Sendable (pre-Swift-6 MetricKit type). Extract all
        // log Strings HERE on the background delivery queue before the actor-boundary hop.
        // Task { @MainActor in } only receives [String], which is Sendable — no warning.
        var messages: [String] = []
        for payload in payloads {
            if let launch = payload.applicationLaunchMetrics {
                messages.append("MetricKit launch: timeToFirstDraw=\(launch.histogrammedTimeToFirstDraw)")
            }
            if let memory = payload.memoryMetrics {
                messages.append("MetricKit memory: peak=\(memory.peakMemoryUsage)")
            }
            messages.append("MetricKit payload: \(payload.jsonRepresentation())")
        }
        Task { @MainActor in
            for message in messages {
                AppLogger.shared.info(message, category: "performance")
            }
        }
    }

    /// MetricKit delivers on arbitrary background queue — `nonisolated` with actor hop.
    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        // CONC-27: MXDiagnosticPayload is non-Sendable. Extract Strings before actor hop.
        // Count crash diagnostics before crossing the actor boundary.
        var messages: [String] = []
        var newCrashCount = 0
        for payload in payloads {
            if let crashes = payload.crashDiagnostics, !crashes.isEmpty {
                newCrashCount += crashes.count
            }
            messages.append("MetricKit diagnostic: \(payload.jsonRepresentation())")
        }
        Task { @MainActor in
            if newCrashCount > 0 {
                self.crashCount += newCrashCount
                AppLogger.shared.error(
                    "MetricKit: \(newCrashCount) crash(es) recorded — total crashes: \(self.crashCount), crashFreeRate: \(String(format: "%.3f", self.crashFreeRate))",
                    category: "performance"
                )
            }
            for message in messages {
                AppLogger.shared.error(message, category: "performance")
            }
        }
    }
}
#endif
