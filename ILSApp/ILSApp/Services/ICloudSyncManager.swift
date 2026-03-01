import Foundation
import Observation

// MARK: - ICloudSyncStatus

/// The current synchronization state of the iCloud key-value store.
enum ICloudSyncStatus: String, Sendable {
    case idle
    case syncing
    case error
    case disabled
}

// MARK: - ICloudSyncManager

/// Manages cross-device preference sync using NSUbiquitousKeyValueStore.
///
/// Provides a typed read/write API over iCloud key-value storage, tracks sync
/// status and last-sync time, and broadcasts `iCloudPreferencesDidChange` when
/// an external device updates shared values.
///
/// Sync can be disabled per device via `setSyncEnabled(_:)`.
/// Uses @Observable for zero-overhead SwiftUI integration.
@MainActor
@Observable
final class ICloudSyncManager {
    static let shared = ICloudSyncManager()

    // MARK: - Observable State

    private(set) var syncStatus: ICloudSyncStatus = .idle
    private(set) var lastSyncDate: Date?
    private(set) var isSyncEnabled: Bool

    // MARK: - Constants

    private enum StorageKey {
        static let syncEnabled = "ils_icloud_sync_enabled"
    }

    /// Keys for encoding notification preferences into a single iCloud dictionary.
    private enum NotifPrefKey {
        static let mcpOfflineAlerts = "mcpOfflineAlerts"
        static let mcpOnlineAlerts = "mcpOnlineAlerts"
        static let sessionCompleteAlerts = "sessionCompleteAlerts"
        static let quietHoursEnabled = "quietHoursEnabled"
        static let quietStartHour = "quietStartHour"
        static let quietEndHour = "quietEndHour"
    }

    /// Direct (localKey → iCloudKey) pairs for scalar preferences synced via
    /// NSUbiquitousKeyValueStore. Each push reads from UserDefaults and writes
    /// to the paired iCloud key; each pull does the reverse.
    static var syncableKeys: [(local: String, iCloud: String)] = [
        (local: AppConstants.serverURLKey,    iCloud: AppConstants.iCloudServerURLKey),
        (local: AppConstants.defaultModelKey, iCloud: AppConstants.iCloudDefaultModelKey),
        (local: "activeHostName",             iCloud: AppConstants.iCloudActiveHostNameKey),
        (local: "colorScheme",                iCloud: "ils_icloud_color_scheme"),
        (local: "enableAgentTeams",           iCloud: "ils_icloud_enable_agent_teams"),
        (local: "selectedThemeID",            iCloud: AppConstants.iCloudActiveThemeKey),
    ]

    /// Shared notification user-info key for the array of changed iCloud keys.
    static let changedKeysUserInfoKey = "changedKeys"

    // MARK: - Private State

    private let store = NSUbiquitousKeyValueStore.default

    /// External-change observer. Stored for cleanup in deinit, though as a singleton
    /// this instance is never deallocated. The closure references ICloudSyncManager.shared
    /// (not self) so no retain cycle exists.
    /// MEM pattern: follows SyncCoordinator observer lifecycle.
    private nonisolated let externalChangeObserver: NSObjectProtocol

    // MARK: - Init / Deinit

    private init() {
        isSyncEnabled = UserDefaults.standard.object(forKey: StorageKey.syncEnabled) as? Bool ?? true

        externalChangeObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { notification in
            Task { @MainActor in
                ICloudSyncManager.shared.handleExternalChange(notification)
            }
        }

        if isSyncEnabled {
            performInitialSync()
        } else {
            syncStatus = .disabled
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(externalChangeObserver)
    }

    // MARK: - Public API

    /// Enable or disable iCloud sync for this device.
    ///
    /// Persisted to `UserDefaults` so the preference survives app restarts.
    func setSyncEnabled(_ enabled: Bool) {
        isSyncEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: StorageKey.syncEnabled)

        if enabled {
            syncStatus = .idle
            performInitialSync()
            AppLogger.shared.info("iCloud sync enabled", category: "icloud")
        } else {
            syncStatus = .disabled
            AppLogger.shared.info("iCloud sync disabled for this device", category: "icloud")
        }
    }

    /// Write a value to the iCloud key-value store.
    ///
    /// No-ops silently when sync is disabled so callers need no guard logic.
    func set(_ value: Any?, forKey key: String) {
        guard isSyncEnabled else { return }
        store.set(value, forKey: key)
        store.synchronize()
        lastSyncDate = Date()
        AppLogger.shared.info("iCloud KV set key '\(key)'", category: "icloud")
    }

    /// Read a value from the iCloud key-value store.
    func object(forKey key: String) -> Any? {
        guard isSyncEnabled else { return nil }
        return store.object(forKey: key)
    }

    /// Read a `String` from the iCloud key-value store.
    func string(forKey key: String) -> String? {
        guard isSyncEnabled else { return nil }
        return store.string(forKey: key)
    }

    /// Read a `Bool` from the iCloud key-value store.
    func bool(forKey key: String) -> Bool {
        guard isSyncEnabled else { return false }
        return store.bool(forKey: key)
    }

    /// Read a `Double` from the iCloud key-value store.
    func double(forKey key: String) -> Double {
        guard isSyncEnabled else { return 0 }
        return store.double(forKey: key)
    }

    /// Read a `[String: Any]` dictionary from the iCloud key-value store.
    func dictionary(forKey key: String) -> [String: Any]? {
        guard isSyncEnabled else { return nil }
        return store.dictionary(forKey: key)
    }

    /// Read an array from the iCloud key-value store.
    func array(forKey key: String) -> [Any]? {
        guard isSyncEnabled else { return nil }
        return store.array(forKey: key)
    }

    /// Remove a key from the iCloud key-value store.
    func removeObject(forKey key: String) {
        guard isSyncEnabled else { return }
        store.removeObject(forKey: key)
        store.synchronize()
        AppLogger.shared.info("iCloud KV removed key '\(key)'", category: "icloud")
    }

    /// Manually trigger synchronization with iCloud.
    ///
    /// Normally the system calls `synchronize()` automatically; call this
    /// after batch writes to request an immediate upload.
    @discardableResult
    func synchronize() -> Bool {
        guard isSyncEnabled else { return false }
        syncStatus = .syncing
        let success = store.synchronize()
        if success {
            lastSyncDate = Date()
            syncStatus = .idle
            AppLogger.shared.info("iCloud KV store synchronized", category: "icloud")
        } else {
            syncStatus = .error
            AppLogger.shared.warning("iCloud KV store synchronize returned false", category: "icloud")
        }
        return success
    }

    // MARK: - Preferences Push / Pull

    /// Push all syncable preferences from local UserDefaults to the iCloud
    /// key-value store and request an immediate upload.
    ///
    /// Call this on app launch and when the app transitions to the active scene
    /// phase. No-ops silently when sync is disabled.
    func syncPreferencesToCloud() {
        guard isSyncEnabled else { return }
        syncStatus = .syncing

        for pair in Self.syncableKeys {
            if let value = UserDefaults.standard.object(forKey: pair.local) {
                store.set(value, forKey: pair.iCloud)
            }
        }

        let notifPrefs: [String: Any] = [
            NotifPrefKey.mcpOfflineAlerts:
                UserDefaults.standard.object(forKey: "notif_mcpOfflineAlerts") as? Bool ?? true,
            NotifPrefKey.mcpOnlineAlerts:
                UserDefaults.standard.object(forKey: "notif_mcpOnlineAlerts") as? Bool ?? false,
            NotifPrefKey.sessionCompleteAlerts:
                UserDefaults.standard.object(forKey: "notif_sessionCompleteAlerts") as? Bool ?? true,
            NotifPrefKey.quietHoursEnabled:
                UserDefaults.standard.object(forKey: "notif_quietHoursEnabled") as? Bool ?? false,
            NotifPrefKey.quietStartHour:
                UserDefaults.standard.object(forKey: "notif_quietStartHour") as? Int ?? 22,
            NotifPrefKey.quietEndHour:
                UserDefaults.standard.object(forKey: "notif_quietEndHour") as? Int ?? 7,
        ]
        store.set(notifPrefs, forKey: AppConstants.iCloudNotificationPrefsKey)

        let success = store.synchronize()
        if success {
            lastSyncDate = Date()
            syncStatus = .idle
            AppLogger.shared.info("Preferences pushed to iCloud KV store", category: "icloud")
        } else {
            syncStatus = .error
            AppLogger.shared.warning("Failed to push preferences to iCloud KV store", category: "icloud")
        }
    }

    /// Pull preferences from the iCloud key-value store into local UserDefaults.
    ///
    /// Called automatically when iCloud reports an external change. Only applies
    /// values present in the store; does not overwrite local prefs when absent.
    func applyCloudPreferences() {
        guard isSyncEnabled else { return }

        for pair in Self.syncableKeys {
            if let value = store.object(forKey: pair.iCloud) {
                UserDefaults.standard.set(value, forKey: pair.local)
            }
        }

        if let notifPrefs = store.dictionary(forKey: AppConstants.iCloudNotificationPrefsKey) {
            if let val = notifPrefs[NotifPrefKey.mcpOfflineAlerts] as? Bool {
                UserDefaults.standard.set(val, forKey: "notif_mcpOfflineAlerts")
            }
            if let val = notifPrefs[NotifPrefKey.mcpOnlineAlerts] as? Bool {
                UserDefaults.standard.set(val, forKey: "notif_mcpOnlineAlerts")
            }
            if let val = notifPrefs[NotifPrefKey.sessionCompleteAlerts] as? Bool {
                UserDefaults.standard.set(val, forKey: "notif_sessionCompleteAlerts")
            }
            if let val = notifPrefs[NotifPrefKey.quietHoursEnabled] as? Bool {
                UserDefaults.standard.set(val, forKey: "notif_quietHoursEnabled")
            }
            if let val = notifPrefs[NotifPrefKey.quietStartHour] as? Int {
                UserDefaults.standard.set(val, forKey: "notif_quietStartHour")
            }
            if let val = notifPrefs[NotifPrefKey.quietEndHour] as? Int {
                UserDefaults.standard.set(val, forKey: "notif_quietEndHour")
            }
        }

        lastSyncDate = Date()
        AppLogger.shared.info("Cloud preferences applied to local UserDefaults", category: "icloud")
    }

    // MARK: - Private

    private func performInitialSync() {
        syncStatus = .syncing
        let success = store.synchronize()
        if success {
            lastSyncDate = Date()
            syncStatus = .idle
            AppLogger.shared.info("iCloud KV store initial sync completed", category: "icloud")
        } else {
            syncStatus = .error
            AppLogger.shared.warning("iCloud KV store initial sync failed", category: "icloud")
        }
    }

    private func handleExternalChange(_ notification: Notification) {
        guard isSyncEnabled else { return }

        let reasonCode = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int ?? -1
        let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []

        let reason: String
        switch reasonCode {
        case NSUbiquitousKeyValueStoreServerChange:
            reason = "server"
        case NSUbiquitousKeyValueStoreInitialSyncChange:
            reason = "initial"
        case NSUbiquitousKeyValueStoreQuotaViolationChange:
            reason = "quota_violation"
            AppLogger.shared.error(
                "iCloud KV quota exceeded — reduce stored data size",
                category: "icloud"
            )
        case NSUbiquitousKeyValueStoreAccountChange:
            reason = "account_change"
            AppLogger.shared.warning(
                "iCloud account changed — preferences may have been reset",
                category: "icloud"
            )
        default:
            reason = "unknown(\(reasonCode))"
        }

        AppLogger.shared.info(
            "iCloud external change: reason=\(reason), keys=[\(changedKeys.joined(separator: ", "))]",
            category: "icloud"
        )

        lastSyncDate = Date()
        syncStatus = .idle

        applyCloudPreferences()

        NotificationCenter.default.post(
            name: .iCloudPreferencesDidChange,
            object: nil,
            userInfo: [ICloudSyncManager.changedKeysUserInfoKey: changedKeys]
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted on the main queue when iCloud externally changes stored preferences.
    ///
    /// The `userInfo` dictionary contains `ICloudSyncManager.changedKeysUserInfoKey`
    /// with an array of the changed key strings.
    static let iCloudPreferencesDidChange = Notification.Name("iCloudPreferencesDidChange")
}
