import Foundation

/// iCloud Key-Value Store wrapper for syncing app settings across devices
actor iCloudKeyValueStore {
    private let store: NSUbiquitousKeyValueStore
    private var changeHandler: ((Notification) -> Void)?

    init(store: NSUbiquitousKeyValueStore = .default) {
        self.store = store
        setupNotifications()
    }

    // MARK: - Synchronization

    /// Explicitly synchronize with iCloud
    /// - Returns: true if synchronization was successful
    func synchronize() -> Bool {
        return store.synchronize()
    }

    // MARK: - String Values

    func getString(forKey key: String) -> String? {
        return store.string(forKey: key)
    }

    func setString(_ value: String?, forKey key: String) throws {
        guard key.count <= 64 else {
            throw iCloudKVSError.keyTooLong(key: key, length: key.count)
        }

        if let value = value {
            guard value.utf8.count <= 1024 * 1024 else {
                throw iCloudKVSError.valueTooLarge(size: value.utf8.count)
            }
            store.set(value, forKey: key)
        } else {
            store.removeObject(forKey: key)
        }
    }

    // MARK: - Bool Values

    func getBool(forKey key: String) -> Bool {
        return store.bool(forKey: key)
    }

    func setBool(_ value: Bool, forKey key: String) throws {
        guard key.count <= 64 else {
            throw iCloudKVSError.keyTooLong(key: key, length: key.count)
        }
        store.set(value, forKey: key)
    }

    // MARK: - Int Values

    func getInt(forKey key: String) -> Int {
        return Int(store.longLong(forKey: key))
    }

    func setInt(_ value: Int, forKey key: String) throws {
        guard key.count <= 64 else {
            throw iCloudKVSError.keyTooLong(key: key, length: key.count)
        }
        store.set(Int64(value), forKey: key)
    }

    // MARK: - Double Values

    func getDouble(forKey key: String) -> Double {
        return store.double(forKey: key)
    }

    func setDouble(_ value: Double, forKey key: String) throws {
        guard key.count <= 64 else {
            throw iCloudKVSError.keyTooLong(key: key, length: key.count)
        }
        store.set(value, forKey: key)
    }

    // MARK: - Data Values

    func getData(forKey key: String) -> Data? {
        return store.data(forKey: key)
    }

    func setData(_ value: Data?, forKey key: String) throws {
        guard key.count <= 64 else {
            throw iCloudKVSError.keyTooLong(key: key, length: key.count)
        }

        if let value = value {
            guard value.count <= 1024 * 1024 else {
                throw iCloudKVSError.valueTooLarge(size: value.count)
            }
            store.set(value, forKey: key)
        } else {
            store.removeObject(forKey: key)
        }
    }

    // MARK: - Array Values

    func getArray(forKey key: String) -> [Any]? {
        return store.array(forKey: key)
    }

    func setArray(_ value: [Any]?, forKey key: String) throws {
        guard key.count <= 64 else {
            throw iCloudKVSError.keyTooLong(key: key, length: key.count)
        }

        if let value = value {
            // Approximate size check - NSUbiquitousKeyValueStore has 1MB total limit
            let estimatedSize = MemoryLayout.size(ofValue: value) * value.count
            guard estimatedSize <= 1024 * 1024 else {
                throw iCloudKVSError.valueTooLarge(size: estimatedSize)
            }
            store.set(value, forKey: key)
        } else {
            store.removeObject(forKey: key)
        }
    }

    // MARK: - Dictionary Values

    func getDictionary(forKey key: String) -> [String: Any]? {
        return store.dictionary(forKey: key)
    }

    func setDictionary(_ value: [String: Any]?, forKey key: String) throws {
        guard key.count <= 64 else {
            throw iCloudKVSError.keyTooLong(key: key, length: key.count)
        }

        if let value = value {
            // Approximate size check
            let estimatedSize = MemoryLayout.size(ofValue: value) * value.count
            guard estimatedSize <= 1024 * 1024 else {
                throw iCloudKVSError.valueTooLarge(size: estimatedSize)
            }
            store.set(value, forKey: key)
        } else {
            store.removeObject(forKey: key)
        }
    }

    // MARK: - Remove Values

    func removeObject(forKey key: String) {
        store.removeObject(forKey: key)
    }

    // MARK: - All Keys

    func allKeys() -> [String] {
        return store.dictionaryRepresentation.keys.map { String($0) }
    }

    // MARK: - Change Notifications

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] notification in
            Task {
                await self?.handleExternalChange(notification)
            }
        }
    }

    private func handleExternalChange(_ notification: Notification) {
        // Extract change reason
        if let userInfo = notification.userInfo,
           let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int {

            switch reason {
            case NSUbiquitousKeyValueStoreServerChange:
                // Values changed on server
                break
            case NSUbiquitousKeyValueStoreInitialSyncChange:
                // Initial sync completed
                break
            case NSUbiquitousKeyValueStoreQuotaViolationChange:
                // Quota exceeded
                break
            case NSUbiquitousKeyValueStoreAccountChange:
                // iCloud account changed
                break
            default:
                break
            }
        }

        // Notify handler if set
        changeHandler?(notification)
    }

    func setChangeHandler(_ handler: @escaping (Notification) -> Void) {
        self.changeHandler = handler
    }
}

// MARK: - Error Types

enum iCloudKVSError: Error, LocalizedError {
    case keyTooLong(key: String, length: Int)
    case valueTooLarge(size: Int)
    case synchronizationFailed
    case quotaExceeded
    case accountUnavailable

    var errorDescription: String? {
        switch self {
        case .keyTooLong(let key, let length):
            return "Key '\(key)' is too long (\(length) characters). Maximum length is 64 characters."
        case .valueTooLarge(let size):
            let sizeMB = Double(size) / (1024 * 1024)
            return "Value is too large (\(String(format: "%.2f", sizeMB)) MB). Maximum size is 1 MB."
        case .synchronizationFailed:
            return "Failed to synchronize with iCloud. Please check your iCloud settings and connection."
        case .quotaExceeded:
            return "iCloud Key-Value Store quota exceeded. Maximum storage is 1 MB."
        case .accountUnavailable:
            return "iCloud account is not available. Please sign in to iCloud in Settings."
        }
    }

    var isRetriable: Bool {
        switch self {
        case .synchronizationFailed:
            return true
        case .keyTooLong, .valueTooLarge, .quotaExceeded, .accountUnavailable:
            return false
        }
    }
}
