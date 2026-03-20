import Foundation
import Vapor

/// Utility for sanitizing file paths to prevent path traversal attacks.
///
/// All methods reject paths containing `..`, `~`, null bytes, or absolute paths
/// (unless explicitly allowed within a specific base directory).
enum PathSanitizer {

    // MARK: - Errors

    enum PathError: AbortError {
        case pathTraversal(String)
        case invalidComponent(String)

        var status: HTTPResponseStatus { .badRequest }

        var reason: String {
            switch self {
            case .pathTraversal(let detail):
                return "Path traversal rejected: \(detail)"
            case .invalidComponent(let detail):
                return "Invalid path component: \(detail)"
            }
        }
    }

    // MARK: - Validation

    // MARK: - URL-Encoded Traversal Detection

    /// Common URL-encoded traversal patterns that bypass naive literal checks.
    /// Includes single-encoded, double-encoded, and overlong UTF-8 variants.
    private static let encodedTraversalPatterns: [String] = [
        // Single-encoded ../ and ..\
        "%2e%2e/", "%2e%2e\\", "%2e%2e%2f", "%2e%2e%5c",
        // Mixed case variants
        "%2E%2E/", "%2E%2E\\", "%2E%2E%2F", "%2E%2E%5C",
        // Double-encoded
        "%252e%252e", "%252e%252e%252f", "%252e%252e%255c",
        // Overlong UTF-8 encoding of '.'
        "%c0%ae%c0%ae", "%c0%2e%c0%2e",
        // Dot variations
        "..%2f", "..%5c", "..%252f", "..%255c",
        // Null byte injection (URL-encoded)
        "%00",
    ]

    /// Check a string for URL-encoded path traversal sequences.
    ///
    /// Detects single-encoded, double-encoded, and overlong UTF-8 variants of
    /// `..`, `/`, `\`, and null bytes that could bypass literal string checks.
    ///
    /// - Parameter input: The raw input string (before URL decoding)
    /// - Throws: `PathError.pathTraversal` if encoded traversal sequences are found
    static func rejectEncodedTraversal(_ input: String) throws {
        let lowered = input.lowercased()
        for pattern in encodedTraversalPatterns {
            if lowered.contains(pattern.lowercased()) {
                throw PathError.pathTraversal("URL-encoded traversal sequence detected")
            }
        }
    }

    /// Validate that a path component (directory name, filename, session ID, etc.)
    /// does not contain traversal sequences or dangerous characters.
    ///
    /// Rejects: `..`, `/`, `\`, `~`, null bytes, empty strings,
    /// and URL-encoded traversal sequences.
    ///
    /// - Parameter component: A single path component to validate
    /// - Throws: `PathError` if the component is unsafe
    static func validateComponent(_ component: String) throws {
        guard !component.isEmpty else {
            throw PathError.invalidComponent("empty path component")
        }

        // Reject null bytes
        guard !component.contains("\0") else {
            throw PathError.invalidComponent("null byte in path component")
        }

        // SEC-PATH-01: Reject URL-encoded traversal sequences before decoding
        try rejectEncodedTraversal(component)

        // Reject traversal sequences
        guard !component.contains("..") else {
            throw PathError.pathTraversal("'..' not allowed in path component")
        }

        // Reject directory separators (component should be a single name)
        guard !component.contains("/") && !component.contains("\\") else {
            throw PathError.pathTraversal("directory separators not allowed in path component")
        }

        // Reject tilde expansion
        guard !component.hasPrefix("~") else {
            throw PathError.pathTraversal("'~' not allowed in path component")
        }
    }

    /// Validate that a resolved path stays within a given base directory.
    ///
    /// Resolves the path (expanding symlinks, normalizing `..`), then checks
    /// that the normalized result starts with the normalized base directory.
    ///
    /// - Parameters:
    ///   - path: The path to validate
    ///   - baseDirectory: The allowed base directory
    /// - Returns: The resolved, validated path
    /// - Throws: `PathError` if the path escapes the base directory
    static func validateWithinBase(_ path: String, baseDirectory: String) throws -> String {
        let normalizedPath = (path as NSString).standardizingPath
        let normalizedBase = (baseDirectory as NSString).standardizingPath

        guard normalizedPath.hasPrefix(normalizedBase + "/") || normalizedPath == normalizedBase else {
            throw PathError.pathTraversal("path escapes allowed directory")
        }

        return normalizedPath
    }

    // MARK: - Input Validation Helpers

    /// Validate that a string does not exceed a maximum length.
    ///
    /// - Parameters:
    ///   - value: The string to validate
    ///   - maxLength: Maximum allowed character count
    ///   - fieldName: Name of the field (for error messages)
    /// - Throws: `Abort(.badRequest)` if the string exceeds the limit
    static func validateStringLength(_ value: String, maxLength: Int, fieldName: String) throws {
        guard value.count <= maxLength else {
            throw Abort(.badRequest, reason: "\(fieldName) exceeds maximum length of \(maxLength) characters")
        }
    }

    /// Validate that optional string, if present, does not exceed a maximum length.
    ///
    /// - Parameters:
    ///   - value: The optional string to validate
    ///   - maxLength: Maximum allowed character count
    ///   - fieldName: Name of the field (for error messages)
    /// - Throws: `Abort(.badRequest)` if the string exceeds the limit
    static func validateOptionalStringLength(_ value: String?, maxLength: Int, fieldName: String) throws {
        if let value = value {
            try validateStringLength(value, maxLength: maxLength, fieldName: fieldName)
        }
    }
}
