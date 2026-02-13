import Foundation
import Security
import LocalAuthentication

/// Secure storage service using iOS Keychain with biometric protection
actor KeychainService {
    private let serviceName: String

    init(serviceName: String = "com.ils.app") {
        self.serviceName = serviceName
    }

    // MARK: - Credential Storage Methods

    /// Save a credential to the Keychain
    /// - Parameters:
    ///   - key: Unique identifier for the credential
    ///   - value: Credential value to store
    ///   - requireBiometrics: Whether to require Face ID/Touch ID to access this credential
    func saveCredential(key: String, value: String, requireBiometrics: Bool = false) async throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        // Delete existing item if present
        try? await deleteCredential(key: key)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // Add biometric protection if requested
        if requireBiometrics {
            guard let accessControl = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .biometryCurrentSet,
                nil
            ) else {
                throw KeychainError.biometricSetupFailed
            }

            query[kSecAttrAccessControl as String] = accessControl
            query.removeValue(forKey: kSecAttrAccessible as String)
        }

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status: status)
        }
    }

    /// Retrieve a credential from the Keychain
    /// - Parameter key: Unique identifier for the credential
    /// - Returns: The stored credential value
    func getCredential(key: String) async throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.readFailed(status: status)
        }

        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return value
    }

    /// Delete a credential from the Keychain
    /// - Parameter key: Unique identifier for the credential
    func deleteCredential(key: String) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status: status)
        }
    }

    /// Retrieve all credential keys stored in the Keychain
    /// - Returns: Array of credential keys
    func getAllCredentials() async throws -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return []
            }
            throw KeychainError.readFailed(status: status)
        }

        guard let items = result as? [[String: Any]] else {
            return []
        }

        return items.compactMap { item in
            item[kSecAttrAccount as String] as? String
        }
    }

    // MARK: - Biometric Availability

    /// Check if biometric authentication is available
    /// - Returns: True if Face ID or Touch ID is available and enrolled
    func isBiometricAuthenticationAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Get the type of biometric authentication available
    /// - Returns: "Face ID", "Touch ID", or nil if not available
    func biometricType() -> String? {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return nil
        }

        switch context.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return nil
        @unknown default:
            return nil
        }
    }
}

// MARK: - Error Types

enum KeychainError: Error, LocalizedError {
    case invalidData
    case itemNotFound
    case saveFailed(status: OSStatus)
    case readFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)
    case biometricSetupFailed
    case biometricAuthenticationFailed

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid data format - could not convert to/from string"
        case .itemNotFound:
            return "Credential not found in Keychain"
        case .saveFailed(let status):
            return "Failed to save credential to Keychain: \(statusMessage(status))"
        case .readFailed(let status):
            return "Failed to read credential from Keychain: \(statusMessage(status))"
        case .deleteFailed(let status):
            return "Failed to delete credential from Keychain: \(statusMessage(status))"
        case .biometricSetupFailed:
            return "Failed to set up biometric protection"
        case .biometricAuthenticationFailed:
            return "Biometric authentication failed - please try again"
        }
    }

    private func statusMessage(_ status: OSStatus) -> String {
        switch status {
        case errSecDuplicateItem:
            return "Item already exists"
        case errSecParam:
            return "Invalid parameters"
        case errSecAllocate:
            return "Memory allocation failed"
        case errSecNotAvailable:
            return "Keychain not available"
        case errSecAuthFailed:
            return "Authentication failed"
        case errSecInteractionNotAllowed:
            return "User interaction not allowed"
        default:
            return "OSStatus code \(status)"
        }
    }
}
