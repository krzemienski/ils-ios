import Foundation
import Observation

// MARK: - ConnectionQuality

/// Classifies connection quality based on measured round-trip latency to the backend.
enum ConnectionQuality: String, Sendable {
    case excellent  // < 50ms
    case good       // < 150ms
    case fair       // < 500ms
    case poor       // >= 500ms
    case offline    // no response

    /// Human-readable label for display in UI.
    var label: String {
        switch self {
        case .excellent: return "Excellent"
        case .good:      return "Good"
        case .fair:      return "Fair"
        case .poor:      return "Poor"
        case .offline:   return "Offline"
        }
    }

    /// Classify latency in milliseconds into a quality tier.
    static func classify(latencyMs: Double) -> ConnectionQuality {
        switch latencyMs {
        case ..<50:  return .excellent
        case ..<150: return .good
        case ..<500: return .fair
        default:     return .poor
        }
    }
}

// MARK: - ConnectionQualityService

/// Periodically measures round-trip latency to the backend health endpoint and
/// classifies connection quality as excellent / good / fair / poor / offline.
///
/// Singleton observable — UI components can bind directly without wiring.
/// Polling interval adapts to Low Power Mode (doubles when LPM is active).
@MainActor
@Observable
final class ConnectionQualityService {
    static let shared = ConnectionQualityService()

    private(set) var quality: ConnectionQuality = .offline
    private(set) var latencyMs: Double?

    /// Server URL used for health pings. Updated by ConnectionManager when URL changes.
    var serverURL: String = AppConstants.defaultServerURL

    @ObservationIgnored private var pollTask: Task<Void, Never>?

    // BATT-02: Restart polling when LPM toggles to apply updated intervals.
    @ObservationIgnored private var lpmObserver: NSObjectProtocol?

    /// URLSession with a short timeout — we classify anything ≥ 500ms as poor,
    /// so a 5s ceiling avoids blocking indefinitely while allowing fair classification.
    @ObservationIgnored private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 5
        return URLSession(configuration: config)
    }()

    private init() {
        lpmObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.pollTask != nil {
                    self.stopPolling()
                    self.startPolling()
                }
            }
        }
        AppLogger.shared.info("ConnectionQualityService initialized", category: "network")
    }

    // MARK: - Polling Control

    func startPolling() {
        guard pollTask == nil else { return }
        let isLPM = LowPowerModeMonitor.shared.isLowPowerModeEnabled
        // BATT-02: Double measurement interval in Low Power Mode.
        let interval: UInt64 = isLPM ? 60_000_000_000 : 30_000_000_000  // 60s LPM / 30s normal
        AppLogger.shared.info(
            "ConnectionQualityService: starting (interval: \(isLPM ? "60s" : "30s"))",
            category: "network"
        )
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                await self.measure()
                try? await Task.sleep(nanoseconds: interval)
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
        AppLogger.shared.info("ConnectionQualityService: stopped", category: "network")
    }

    // MARK: - Measurement

    /// Perform a single latency measurement and update `quality` / `latencyMs`.
    func measure() async {
        // NET-MED-2: Skip network requests when device has no connectivity.
        guard NetworkMonitor.shared.isConnected else {
            quality = .offline
            latencyMs = nil
            return
        }

        guard let url = URL(string: "\(serverURL)/health") else {
            quality = .offline
            latencyMs = nil
            return
        }

        let start = Date()
        do {
            let (_, response) = try await session.data(from: url)
            let elapsed = Date().timeIntervalSince(start) * 1_000  // convert to ms
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                latencyMs = elapsed
                quality = ConnectionQuality.classify(latencyMs: elapsed)
                AppLogger.shared.info(
                    "Quality: \(quality.rawValue) (\(String(format: "%.0f", elapsed))ms)",
                    category: "network"
                )
            } else {
                latencyMs = nil
                quality = .offline
            }
        } catch {
            latencyMs = nil
            quality = .offline
            AppLogger.shared.warning(
                "Quality measurement failed: \(error.localizedDescription)",
                category: "network"
            )
        }
    }
}
