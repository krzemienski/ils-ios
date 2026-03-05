import SwiftUI
import Observation
import ILSShared

#if os(iOS)
import UIKit
#endif

// MARK: - Density Manager

/// Manages information density selection and persistence.
///
/// Controls the information density level across the app, adjusting spacing, typography,
/// and element sizes for optimal viewing on different devices and use cases.
/// Persists user's choice to UserDefaults and supports iCloud synchronization.
///
/// ## Topics
/// ### Properties
/// - ``currentDensity`` - Currently active density level
///
/// ### Methods
/// - ``setDensity(_:)`` - Switch to a different density level
/// - ``recommendedDensity()`` - Get device-appropriate default density
@MainActor
@Observable
class DensityManager {
    /// Currently active density level.
    private(set) var currentDensity: InformationDensity = .standard

    private static let densityKey = "selectedDensityLevel"

    /// Observer token for `iCloudPreferencesDidChange` notifications.
    @ObservationIgnored private var iCloudChangeObserver: NSObjectProtocol?

    /// Shared singleton instance.
    static let shared = DensityManager()

    // MARK: - Device-Based Defaults

    /// Detects the recommended density level based on the current device.
    ///
    /// - iPhone: `.compact` — Maximize information density on smaller screens
    /// - iPad: `.standard` — Balanced approach for medium-sized screens
    /// - Mac: `.comfortable` — Generous spacing for large desktop displays
    ///
    /// - Returns: The recommended `InformationDensity` for this device.
    static func recommendedDensity() -> InformationDensity {
        #if os(iOS)
        switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            return .compact
        case .pad:
            return .standard
        default:
            return .standard
        }
        #elseif os(macOS)
        return .comfortable
        #else
        return .standard
        #endif
    }

    private init() {
        // Load persisted density level, or use device-recommended default
        if let rawValue = UserDefaults.standard.string(forKey: Self.densityKey),
           let density = InformationDensity(rawValue: rawValue) {
            currentDensity = density
        } else {
            currentDensity = Self.recommendedDensity()
        }

        // Listen for iCloud sync changes
        iCloudChangeObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            if let rawValue = UserDefaults.standard.string(forKey: Self.densityKey),
               let density = InformationDensity(rawValue: rawValue),
               density != self.currentDensity {
                self.currentDensity = density
            }
        }
    }

    deinit {
        if let observer = iCloudChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Switch to a different density level.
    ///
    /// - Parameter density: The density level to activate.
    func setDensity(_ density: InformationDensity) {
        guard density != currentDensity else { return }
        currentDensity = density
        UserDefaults.standard.set(density.rawValue, forKey: Self.densityKey)
    }
}

// MARK: - Density Environment Key

struct DensityEnvironmentKey: EnvironmentKey {
    static let defaultValue: InformationDensity = .standard
}

extension EnvironmentValues {
    var density: InformationDensity {
        get { self[DensityEnvironmentKey.self] }
        set { self[DensityEnvironmentKey.self] = newValue }
    }
}
