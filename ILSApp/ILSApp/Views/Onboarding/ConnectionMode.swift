import Foundation

/// Connection mode for server setup.
enum ConnectionMode: String, CaseIterable, Identifiable {
    case local = "Local"
    case remote = "Remote"
    case tunnel = "Tunnel"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .local: return "desktopcomputer"
        case .remote: return "network"
        case .tunnel: return "globe"
        }
    }
}
