import Foundation
import Observation
import ILSShared
import SwiftUI

/// ViewModel for the Version Monitor feature.
/// Tracks Claude Code CLI version, checks for updates, and monitors compatibility.
///
/// Supports periodic background checks for updates with configurable intervals (daily/weekly).
/// Check settings are stored in UserDefaults and can be configured via NotificationPreferencesView.
@MainActor
@Observable
class VersionMonitorViewModel: BaseViewModel {
    var currentVersion: CurrentVersionResponse?
    var versionHistory: VersionHistoryResponse?
    var updateCheck: UpdateCheckResponse?
    var compatibility: CompatibilityCheckResponse?

    var isLoadingVersion = false
    var isLoadingHistory = false
    var isCheckingUpdates = false
    var isCheckingCompatibility = false

    /// Load all version-related data in parallel.
    func loadAll() async {
        async let versionTask: () = loadCurrentVersion()
        async let historyTask: () = loadVersionHistory()
        async let updatesTask: () = checkForUpdates()
        async let compatibilityTask: () = checkCompatibility()
        _ = await (versionTask, historyTask, updatesTask, compatibilityTask)
    }

    /// Load the current Claude Code CLI version.
    func loadCurrentVersion() async {
        guard let client else { return }
        isLoadingVersion = true
        defer { isLoadingVersion = false }

        do {
            let response: APIResponse<CurrentVersionResponse> = try await client.get("/system/version/current")
            currentVersion = response.data
        } catch {
            self.error = error
        }
    }

    /// Load the version history showing past detected versions.
    func loadVersionHistory() async {
        guard let client else { return }
        isLoadingHistory = true
        defer { isLoadingHistory = false }

        do {
            let response: APIResponse<VersionHistoryResponse> = try await client.get("/system/version/history")
            versionHistory = response.data
        } catch {
            self.error = error
        }
    }

    /// Check for available Claude Code CLI updates from GitHub.
    func checkForUpdates() async {
        guard let client else { return }
        isCheckingUpdates = true
        defer { isCheckingUpdates = false }

        do {
            let response: APIResponse<UpdateCheckResponse> = try await client.get("/system/version/check-updates")
            updateCheck = response.data

            // Post notification if update is available (macOS only)
            #if os(macOS)
            if let updateData = updateCheck,
               updateData.updateAvailable,
               let currentVer = currentVersion?.version {
                let releaseNotes = updateData.changelog?.prefix(100).description
                await NotificationManager.shared.postVersionUpdateNotification(
                    currentVersion: currentVer,
                    newVersion: updateData.latestVersion,
                    releaseNotes: releaseNotes
                )
            }
            #endif
        } catch {
            self.error = error
        }
    }

    /// Check compatibility between ILS version and Claude Code CLI version.
    /// - Parameter ilsVersion: The ILS app version (defaults to bundle version).
    func checkCompatibility(ilsVersion: String? = nil) async {
        guard let client else { return }
        isCheckingCompatibility = true
        defer { isCheckingCompatibility = false }

        let version = ilsVersion ?? Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

        do {
            let response: APIResponse<CompatibilityCheckResponse> = try await client.get(
                "/system/version/compatibility?ils_version=\(version)"
            )
            compatibility = response.data
        } catch {
            self.error = error
        }
    }

    // MARK: - Computed Properties

    /// Whether an update is available for the CLI.
    var hasUpdateAvailable: Bool {
        updateCheck?.updateAvailable ?? false
    }

    /// Whether the current CLI version has breaking changes.
    var hasBreakingChanges: Bool {
        updateCheck?.hasBreakingChanges ?? false
    }

    /// Whether the CLI and ILS versions are compatible.
    var isCompatible: Bool {
        compatibility?.isCompatible ?? true
    }

    /// Compatibility status for display.
    var compatibilityStatus: CompatibilityCheckResponse.CompatibilityStatus {
        compatibility?.status ?? .unknown
    }

    /// User-facing compatibility message.
    var compatibilityMessage: String {
        compatibility?.message ?? "Compatibility status unknown"
    }

    /// Total number of version changes detected.
    var versionChangeCount: Int {
        versionHistory?.totalCount ?? 0
    }

    /// Whether any version data is currently loading.
    var isLoadingAny: Bool {
        isLoadingVersion || isLoadingHistory || isCheckingUpdates || isCheckingCompatibility
    }

    // MARK: - Periodic Background Checks

    /// Check if a periodic update check should run based on user preferences.
    /// - Returns: True if enough time has passed since the last check based on the configured interval.
    func shouldRunPeriodicCheck() -> Bool {
        let defaults = UserDefaults.standard

        // Check if periodic checks are enabled
        guard defaults.bool(forKey: "versionCheckEnabled") else {
            return false
        }

        // Get last check timestamp
        guard let lastCheck = defaults.object(forKey: "versionCheckLastRun") as? Date else {
            // Never checked before, so we should check now
            return true
        }

        let interval = defaults.string(forKey: "versionCheckInterval") ?? "daily"
        let now = Date()

        switch interval {
        case "daily":
            // Check if 24 hours have passed
            let dayInSeconds: TimeInterval = 24 * 60 * 60
            return now.timeIntervalSince(lastCheck) >= dayInSeconds
        case "weekly":
            // Check if 7 days have passed
            let weekInSeconds: TimeInterval = 7 * 24 * 60 * 60
            return now.timeIntervalSince(lastCheck) >= weekInSeconds
        default:
            return false
        }
    }

    /// Perform a periodic background check for updates if the configured interval has elapsed.
    /// Updates the last check timestamp and loads current version data.
    func performPeriodicCheckIfNeeded() async {
        guard shouldRunPeriodicCheck() else {
            return
        }

        // Update last check timestamp
        UserDefaults.standard.set(Date(), forKey: "versionCheckLastRun")

        // Perform the update check
        await checkForUpdates()

        // Also refresh current version to ensure we have latest data
        await loadCurrentVersion()
    }
}
