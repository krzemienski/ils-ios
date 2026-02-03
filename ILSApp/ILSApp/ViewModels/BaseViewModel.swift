import Foundation

/// Generic base ViewModel that provides common CRUD operations and state management
/// for list-based ViewModels that interact with the ILS API.
///
/// Subclasses should:
/// - Specify the Item type (must be Decodable and Identifiable)
/// - Override `resourcePath` to provide the API endpoint
/// - Override `emptyStateText` for custom empty state messaging
/// - Override `loadingStateText` for custom loading state messaging
@MainActor
class BaseViewModel<Item: Decodable & Identifiable>: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading = false
    @Published var error: Error?

    internal let client = APIClient()

    /// The API resource path (e.g., "/projects", "/sessions")
    /// Subclasses must override this property
    var resourcePath: String {
        fatalError("Subclasses must override resourcePath")
    }

    /// Text to display in loading state
    /// Override in subclass for custom messaging
    var loadingStateText: String {
        "Loading..."
    }

    /// Text to display in empty state
    /// Override in subclass for custom messaging
    var emptyStateText: String {
        if isLoading {
            return loadingStateText
        }
        return items.isEmpty ? "No items yet" : ""
    }

    // MARK: - Common CRUD Operations

    /// Load items from the API
    func loadItems() async {
        isLoading = true
        error = nil

        do {
            let response: APIResponse<ListResponse<Item>> = try await client.get(resourcePath)
            if let data = response.data {
                items = data.items
            }
        } catch {
            self.error = error
            print("❌ Failed to load items from \(resourcePath): \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Retry loading items
    func retryLoad() async {
        await loadItems()
    }

    /// Create a new item
    /// - Parameters:
    ///   - body: The request body to send to the API
    /// - Returns: The created item, or nil if creation failed
    func createItem<Body: Encodable>(body: Body) async -> Item? {
        do {
            let response: APIResponse<Item> = try await client.post(resourcePath, body: body)
            if let item = response.data {
                items.append(item)
                return item
            }
        } catch {
            self.error = error
            print("❌ Failed to create item at \(resourcePath): \(error.localizedDescription)")
        }
        return nil
    }

    /// Update an existing item
    /// - Parameters:
    ///   - id: The ID of the item to update
    ///   - body: The request body to send to the API
    /// - Returns: The updated item, or nil if update failed
    func updateItem<Body: Encodable>(id: Item.ID, body: Body) async -> Item? {
        do {
            let response: APIResponse<Item> = try await client.put("\(resourcePath)/\(id)", body: body)
            if let updated = response.data {
                if let index = items.firstIndex(where: { $0.id == id }) {
                    items[index] = updated
                }
                return updated
            }
        } catch {
            self.error = error
            print("❌ Failed to update item at \(resourcePath)/\(id): \(error.localizedDescription)")
        }
        return nil
    }

    /// Delete an item
    /// - Parameter id: The ID of the item to delete
    func deleteItem(id: Item.ID) async {
        do {
            let _: APIResponse<DeletedResponse> = try await client.delete("\(resourcePath)/\(id)")
            items.removeAll { $0.id == id }
        } catch {
            self.error = error
            print("❌ Failed to delete item at \(resourcePath)/\(id): \(error.localizedDescription)")
        }
    }
}

// MARK: - Common Response Types

/// Standard response for delete operations
struct DeletedResponse: Decodable {
    let deleted: Bool
}
