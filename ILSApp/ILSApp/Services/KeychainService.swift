import Foundation
import Security

/// Secure credential storage service using iOS Keychain
actor KeychainService {
    private let serviceName: String

    init(serviceName: String = "com.ils.app.ssh") {
        self.serviceName = serviceName
    }

    // MARK: - Password Storage

    /// Save a password for an SSH server
    /// - Parameters:
    ///   - serverId: Unique identifier for the SSH server
    ///   - password: Password to store securely
    func savePassword(serverId: String, password: String) async throws {
        guard let passwordData = password.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        try await save(data: passwordData, account: "\(serverId)-password")
    }

    /// Load a password for an SSH server
    /// - Parameter serverId: Unique identifier for the SSH server
    /// - Returns: The stored password, or nil if not found
    func loadPassword(serverId: String) async throws -> String? {
        guard let data = try await load(account: "\(serverId)-password") else {
            return nil
        }

        guard let password = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return password
    }

    // MARK: - Private Key Storage

    /// Save an SSH private key for a server
    /// - Parameters:
    ///   - serverId: Unique identifier for the SSH server
    ///   - privateKey: Private key content to store securely
    func saveKey(serverId: String, privateKey: String) async throws {
        guard let keyData = privateKey.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        try await save(data: keyData, account: "\(serverId)-key")
    }

    /// Load an SSH private key for a server
    /// - Parameter serverId: Unique identifier for the SSH server
    /// - Returns: The stored private key, or nil if not found
    func loadKey(serverId: String) async throws -> String? {
        guard let data = try await load(account: "\(serverId)-key") else {
            return nil
        }

        guard let privateKey = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return privateKey
    }

    // MARK: - Deletion

    /// Delete all credentials (password and key) for an SSH server
    /// - Parameter serverId: Unique identifier for the SSH server
    func delete(serverId: String) async throws {
        // Delete password
        try await deleteItem(account: "\(serverId)-password")

        // Delete key (may not exist, so ignore "not found" errors)
        do {
            try await deleteItem(account: "\(serverId)-key")
        } catch KeychainError.itemNotFound {
            // Key doesn't exist, which is fine
        }
    }

    // MARK: - Generic Keychain Operations

    private func save(data: Data, account: String) async throws {
        // First try to update existing item
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        var status = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)

        // If item doesn't exist, create it
        if status == errSecItemNotFound {
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: account,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]

            status = SecItemAdd(addQuery as CFDictionary, nil)
        }

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status: status)
        }
    }

    private func load(account: String) async throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.loadFailed(status: status)
        }

        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }

        return data
    }

    private func deleteItem(account: String) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecItemNotFound {
            throw KeychainError.itemNotFound
        }

        guard status == errSecSuccess else {
            throw KeychainError.deleteFailed(status: status)
        }
    }
}

// MARK: - Error Types

enum KeychainError: Error, LocalizedError {
    case invalidData
    case itemNotFound
    case saveFailed(status: OSStatus)
    case loadFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Failed to convert data to/from string"
        case .itemNotFound:
            return "Item not found in keychain"
        case .saveFailed(let status):
            return "Failed to save to keychain: \(securityErrorMessage(status))"
        case .loadFailed(let status):
            return "Failed to load from keychain: \(securityErrorMessage(status))"
        case .deleteFailed(let status):
            return "Failed to delete from keychain: \(securityErrorMessage(status))"
        }
    }

    private func securityErrorMessage(_ status: OSStatus) -> String {
        if let errorMessage = SecCopyErrorMessageString(status, nil) as String? {
            return "\(status) - \(errorMessage)"
        }
        return "OSStatus: \(status)"
    }
}
