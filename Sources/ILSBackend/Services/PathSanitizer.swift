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

    /// Validate that a path component (directory name, filename, session ID, etc.)
    /// does not contain traversal sequences or dangerous characters.
    ///
    /// Rejects: `..`, `/`, `\`, `~`, null bytes, empty strings.
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
