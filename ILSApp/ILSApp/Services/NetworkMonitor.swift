import Foundation
import Network
import Observation

// MARK: - Connection Type

enum ConnectionType: String, Sendable {
    case wifi
    case cellular
    case wiredEthernet
    case unknown
}

// MARK: - NetworkMonitor

/// Monitors device network connectivity using NWPathMonitor.
///
/// Publishes `isConnected` and `connectionType` for UI reactivity.
/// Uses @Observable for zero-overhead SwiftUI integration.
@MainActor
@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private(set) var isConnected: Bool = true
    private(set) var connectionType: ConnectionType = .unknown

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.ils.app.networkMonitor", qos: .utility)

    private init() {
        startMonitoring()
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            let type = Self.mapConnectionType(path)

            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasConnected = self.isConnected
                self.isConnected = connected
                self.connectionType = type

                if connected && !wasConnected {
                    AppLogger.shared.info(
                        "Network restored (\(type.rawValue))",
                        category: "network"
                    )
                    NotificationCenter.default.post(
                        name: .networkDidBecomeAvailable,
                        object: nil
                    )
                } else if !connected && wasConnected {
                    AppLogger.shared.warning(
                        "Network lost",
                        category: "network"
                    )
                }
            }
        }
        monitor.start(queue: monitorQueue)
        AppLogger.shared.info("NetworkMonitor started", category: "network")
    }

    private nonisolated static func mapConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wiredEthernet
        } else {
            return .unknown
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let networkDidBecomeAvailable = Notification.Name("networkDidBecomeAvailable")
}
