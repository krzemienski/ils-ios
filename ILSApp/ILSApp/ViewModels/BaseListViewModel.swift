import Foundation
import ILSShared

/// Base class for list-based view models.
///
/// Provides common functionality for ViewModels that manage lists of items:
/// - Item storage with search filtering
/// - Loading/error state management
/// - API client configuration
///
/// This is a minimal extraction for future use. Existing ViewModels have NOT been
/// refactored to inherit from this class yet (too risky for incremental changes).
@MainActor
class BaseListViewModel<Item: Identifiable & Decodable>: ObservableObject {
    /// Items displayed in the list.
    @Published var items: [Item] = []

    /// Loading state indicator.
    @Published var isLoading = false

    /// Error from last operation.
    @Published var error: Error?

    /// Search query text.
    @Published var searchText = ""

    /// API client for backend communication.
    var client: APIClient?

    /// Configure the view model with an API client.
    /// - Parameter client: The API client to use for requests
    func configure(client: APIClient) {
        self.client = client
    }
}
