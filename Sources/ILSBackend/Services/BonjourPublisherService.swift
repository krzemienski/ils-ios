import Foundation

/// Manages Bonjour/mDNS service publishing for backend auto-discovery.
///
/// Publishes an `_ils._tcp` service on the local network so iOS clients
/// can discover the backend without manual IP configuration.
///
/// Uses `@MainActor` to ensure `NetService` runs on the main RunLoop,
/// which is required for Bonjour registration to function correctly.
@MainActor
final class BonjourPublisherService: NSObject {
    // MARK: - State

    private var netService: NetService?
    private var isPublishing: Bool = false

    // MARK: - Constants

    static let serviceType = "_ils._tcp."
    static let serviceDomain = "local."
    static let version = "1.0"

    // MARK: - Public API

    /// Start publishing the Bonjour service on the given port.
    func start(port: Int) {
        guard !isPublishing else { return }

        let hostname = Self.localHostname()
        let name = "\(hostname)-ils"

        let service = NetService(
            domain: Self.serviceDomain,
            type: Self.serviceType,
            name: name,
            port: Int32(port)
        )

        let txtData = Self.buildTXTRecord(hostname: hostname, port: port, version: Self.version)
        service.setTXTRecord(txtData)

        service.schedule(in: .main, forMode: .common)
        service.delegate = self
        service.publish()

        self.netService = service
        self.isPublishing = true
    }

    /// Stop publishing the Bonjour service.
    func stop() {
        netService?.stop()
        netService?.remove(from: .main, forMode: .common)
        netService = nil
        isPublishing = false
    }

    /// Whether the service is currently published.
    var publishing: Bool { isPublishing }

    // MARK: - Private Helpers

    private static func localHostname() -> String {
        ProcessInfo.processInfo.hostName
            .replacingOccurrences(of: ".local", with: "")
    }

    private static func buildTXTRecord(hostname: String, port: Int, version: String) -> Data {
        let dict: [String: Data] = [
            "hostname": Data(hostname.utf8),
            "port": Data(String(port).utf8),
            "version": Data(version.utf8)
        ]
        return NetService.data(fromTXTRecord: dict)
    }
}

// MARK: - NetServiceDelegate

extension BonjourPublisherService: NetServiceDelegate {
    nonisolated func netServiceDidPublish(_ sender: NetService) {
        // Service published successfully — no action needed
    }

    nonisolated func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        // Publication failed — service will not be discoverable
    }

    nonisolated func netServiceDidStop(_ sender: NetService) {
        Task { @MainActor in self.isPublishing = false }
    }
}
