import Foundation
import Observation

// MARK: - KeyboardShortcutConfig

/// A custom keyboard shortcut binding for a command.
///
/// Stores the key character and modifier flags, with a computed display string
/// using standard macOS/iOS modifier symbols (e.g. "⌘⇧K").
struct KeyboardShortcutConfig: Codable {
    /// The key character (single character, e.g. "k").
    let key: String

    /// Modifier names (e.g. ["command", "shift"]).
    let modifiers: [String]

    /// Human-readable shortcut display string computed from `modifiers` and `key`.
    ///
    /// Example: modifiers: ["command", "shift"], key: "k" → "⌘⇧K"
    var displayString: String {
        let modifierSymbols = modifiers.compactMap { Self.symbol(for: $0) }.joined()
        return modifierSymbols + key.uppercased()
    }

    // MARK: - Private Helpers

    private static func symbol(for modifier: String) -> String? {
        switch modifier.lowercased() {
        case "command":  return "⌘"
        case "shift":    return "⇧"
        case "option":   return "⌥"
        case "control":  return "⌃"
        default:         return nil
        }
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case key
        case modifiers
    }
}

// MARK: - KeyboardShortcutStore

/// Service that persists custom keyboard shortcut bindings to UserDefaults.
///
/// Maintains a dictionary mapping command IDs to their custom `KeyboardShortcutConfig`.
/// Supports export/import of the full binding set as JSON for sharing or backup.
///
/// Usage:
/// ```swift
/// let store = KeyboardShortcutStore()
/// store.setBinding(commandId: "new-session", config: KeyboardShortcutConfig(key: "n", modifiers: ["command", "option"]))
/// ```
@Observable
@MainActor
final class KeyboardShortcutStore {

    // MARK: - Properties

    /// Custom shortcut bindings keyed by command ID.
    /// Only commands that have been overridden from their defaults appear here.
    private(set) var customBindings: [String: KeyboardShortcutConfig] = [:]

    // MARK: - Init

    init() {
        load()
    }

    // MARK: - Public API

    /// Returns the custom binding for the given command ID, or `nil` if no override exists.
    func binding(for commandId: String) -> KeyboardShortcutConfig? {
        customBindings[commandId]
    }

    /// Sets a custom binding for the given command ID and persists the change.
    func setBinding(commandId: String, config: KeyboardShortcutConfig) {
        customBindings[commandId] = config
        save()
    }

    /// Removes the custom binding for the given command ID, restoring its default.
    func clearBinding(commandId: String) {
        customBindings.removeValue(forKey: commandId)
        save()
    }

    /// Removes all custom bindings, restoring all commands to their defaults.
    func resetToDefaults() {
        customBindings.removeAll()
        UserDefaults.standard.removeObject(forKey: AppConstants.keyboardShortcutBindingsKey)
    }

    /// Encodes the current custom bindings as JSON data for export.
    ///
    /// - Returns: Encoded JSON `Data`, or `nil` if encoding fails.
    func exportAsJSON() -> Data? {
        try? JSONEncoder().encode(customBindings)
    }

    /// Replaces the current custom bindings with those decoded from `data`.
    ///
    /// - Parameter data: JSON-encoded `[String: KeyboardShortcutConfig]`.
    /// - Returns: `true` if decoding and persistence succeeded; `false` otherwise.
    @discardableResult
    func importFromJSON(_ data: Data) -> Bool {
        guard let decoded = try? JSONDecoder().decode([String: KeyboardShortcutConfig].self, from: data) else {
            return false
        }
        customBindings = decoded
        save()
        return true
    }

    // MARK: - Persistence

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: AppConstants.keyboardShortcutBindingsKey),
            let decoded = try? JSONDecoder().decode([String: KeyboardShortcutConfig].self, from: data)
        else {
            return
        }
        customBindings = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(customBindings) else { return }
        UserDefaults.standard.set(data, forKey: AppConstants.keyboardShortcutBindingsKey)
    }
}
