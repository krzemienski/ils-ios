import Foundation
import Observation

// MARK: - LowPowerModeMonitor

/// Monitors device Low Power Mode state using ProcessInfo notifications.
///
/// Publishes `isLowPowerModeEnabled` for polling services to adapt intervals.
/// Models on NetworkMonitor singleton pattern. Uses @Observable for SwiftUI integration.
@MainActor
@Observable
final class LowPowerModeMonitor {
    static let shared = LowPowerModeMonitor()

    private(set) var isLowPowerModeEnabled: Bool

    // CONC-12: No deinit needed — singleton lives for process lifetime. Observer removed automatically at exit.
    @ObservationIgnored private var observer: NSObjectProtocol?

    private init() {
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled

        observer = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            let enabled = ProcessInfo.processInfo.isLowPowerModeEnabled
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isLowPowerModeEnabled = enabled
                AppLogger.shared.info(
                    "Low Power Mode \(enabled ? "enabled" : "disabled")",
                    category: "power"
                )
            }
        }

        AppLogger.shared.info(
            "LowPowerModeMonitor started (LPM: \(isLowPowerModeEnabled))",
            category: "power"
        )
    }

}
