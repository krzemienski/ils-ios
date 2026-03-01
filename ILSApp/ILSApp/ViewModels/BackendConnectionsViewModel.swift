import Foundation
import Observation
import ILSShared

/// View model for the backend connections management screen.
///
/// Delegates all persistence and health polling to ``BackendManager``.
/// Exposes the manager's `backends` and `activeBackendId` as computed properties
/// so that `@Observable` observation chains propagate through to the source of truth.
@MainActor
@Observable
final class BackendConnectionsViewModel {

    // MARK: - Preset Colors

    /// Eight preset hex color strings offered to the user when adding a backend.
    static let colorPresets: [String] = [
        "#5E5CE6", // Indigo
        "#34C759", // Green
        "#FF9500", // Orange
        "#FF3B30", // Red
        "#007AFF", // Blue
        "#AF52DE", // Purple
        "#FF2D55", // Pink
        "#5856D7"  // Deep indigo
    ]

    // MARK: - State

    /// All persisted backend connection profiles — forwards BackendManager's authoritative list.
    var backends: [BackendConnection] { backendManager.backends }

    /// The ID of the currently active backend.
    var activeBackendId: UUID? { backendManager.activeBackendId }

    var isLoading = false
    var loadError: String?

    /// Name of the most recently activated backend, used to trigger the success banner.
    /// Set by `setActive(id:)` and cleared by the view after the banner auto-dismisses.
    var lastActivatedBackendName: String?

    // MARK: - Private

    @ObservationIgnored private let backendManager: BackendManager

    // MARK: - Init

    init(backendManager: BackendManager = .shared) {
        self.backendManager = backendManager
    }

    // MARK: - Load

    /// Loads all persisted backend connection profiles from the store.
    func loadBackends() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        await backendManager.loadBackends()
    }

    // MARK: - CRUD

    /// Adds a new backend connection with the given attributes.
    ///
    /// - Parameters:
    ///   - name: Display name for the backend.
    ///   - url: Full URL of the backend (e.g., "http://192.168.1.10:9999").
    ///   - apiKey: Optional API key stored securely in the Keychain.
    ///   - colorHex: Hex color for visual differentiation (default: first preset).
    func addBackend(
        name: String,
        url: String,
        apiKey: String? = nil,
        colorHex: String = BackendConnectionsViewModel.colorPresets[0]
    ) async {
        let connection = BackendConnection(name: name, url: url, colorHex: colorHex)
        await backendManager.add(connection, apiKey: apiKey)
    }

    /// Removes the backend with the given ID.
    func removeBackend(id: UUID) async {
        await backendManager.remove(id: id)
    }

    /// Marks the backend with the given ID as active and triggers the success banner.
    func setActive(id: UUID) async {
        guard let backend = backends.first(where: { $0.id == id }) else { return }
        await backendManager.setActive(id: id)
        lastActivatedBackendName = backend.name
    }

    // MARK: - Health Polling

    /// Starts periodic health polling, delegating energy-aware interval logic to ``BackendManager``.
    func startHealthPolling(interval: TimeInterval = 30) {
        backendManager.startHealthPolling(interval: interval)
    }

    /// Stops health polling.
    func stopHealthPolling() {
        backendManager.stopHealthPolling()
    }

    /// Fires an immediate single health check on all backends without waiting for the next
    /// scheduled poll interval. Used by the refresh button in ``BackendHealthDashboardView``.
    func pollNow() async {
        await backendManager.pollNow()
    }
}
