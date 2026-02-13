import Foundation
import CloudKit

@MainActor
class SyncViewModel: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: CloudKitServiceError?
    @Published var isAccountAvailable = false
    @Published var isSyncEnabled = true

    private var cloudKitService: CloudKitService?
    private var keyValueStore: iCloudKeyValueStore?

    init() {}

    func configure(cloudKitService: CloudKitService, keyValueStore: iCloudKeyValueStore) {
        self.cloudKitService = cloudKitService
        self.keyValueStore = keyValueStore
    }

    /// Status text for UI display
    var statusText: String {
        if isSyncing {
            return "Syncing..."
        }

        if let error = syncError {
            return "Sync failed"
        }

        if !isAccountAvailable {
            return "iCloud unavailable"
        }

        if !isSyncEnabled {
            return "Sync disabled"
        }

        if let lastSync = lastSyncDate {
            return "Last synced: \(formatSyncDate(lastSync))"
        }

        return "Not synced"
    }

    /// Check iCloud account availability
    func checkAccountStatus() async {
        guard let cloudKitService else { return }

        do {
            let available = try await cloudKitService.checkAccountStatus()
            isAccountAvailable = available
            syncError = nil
        } catch let error as CloudKitServiceError {
            isAccountAvailable = false
            syncError = error
        } catch {
            isAccountAvailable = false
        }
    }

    /// Perform full sync of all data
    func sync() async {
        guard let cloudKitService, let keyValueStore else { return }
        guard isSyncEnabled else { return }

        isSyncing = true
        syncError = nil

        do {
            // Check account status first
            let available = try await cloudKitService.checkAccountStatus()
            isAccountAvailable = available

            guard available else {
                isSyncing = false
                return
            }

            // Setup CloudKit zone and subscriptions
            try await cloudKitService.setupZone()
            try await cloudKitService.setupSubscriptions()

            // Sync settings via Key-Value Store
            _ = await keyValueStore.synchronize()

            // Update last sync date
            lastSyncDate = Date()
            syncError = nil

        } catch let error as CloudKitServiceError {
            syncError = error
        } catch {
            // Handle unexpected errors
        }

        isSyncing = false
    }

    /// Retry sync after error
    func retrySync() async {
        await sync()
    }

    /// Toggle sync on/off
    func toggleSync() {
        isSyncEnabled.toggle()

        // Save preference to UserDefaults
        UserDefaults.standard.set(isSyncEnabled, forKey: "iCloudSyncEnabled")

        if isSyncEnabled {
            Task {
                await sync()
            }
        }
    }

    /// Load sync preferences
    func loadPreferences() {
        isSyncEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
    }

    // MARK: - Helpers

    private func formatSyncDate(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
}
