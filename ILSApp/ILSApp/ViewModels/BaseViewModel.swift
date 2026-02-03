import Foundation
import ILSShared

/// Generic base ViewModel that provides common CRUD operations and state management
/// for list-based ViewModels that interact with the ILS API.
///
/// ## Purpose
///
/// This base class eliminates the boilerplate code that was duplicated across multiple ViewModels
/// (ProjectsViewModel, SessionsViewModel, SkillsViewModel, MCPViewModel, PluginsViewModel).
/// It centralizes common functionality for loading, creating, updating, and deleting items,
/// along with consistent error handling and loading state management.
///
/// ## Usage Pattern
///
/// To use BaseViewModel, create a subclass that:
/// 1. Specifies the Item type (must conform to `Decodable` and `Identifiable`)
/// 2. Overrides `resourcePath` to provide the API endpoint
/// 3. Optionally overrides `loadingStateText` and `emptyStateText` for custom messaging
/// 4. Optionally adds convenience methods that wrap the base CRUD operations
///
/// ## Example
///
/// ```swift
/// @MainActor
/// class ProjectsViewModel: BaseViewModel<Project> {
///     // 1. Convenience accessor for type-specific access
///     var projects: [Project] {
///         items
///     }
///
///     // 2. Required: Specify the API endpoint
///     override var resourcePath: String {
///         "/projects"
///     }
///
///     // 3. Optional: Customize loading state text
///     override var loadingStateText: String {
///         "Loading projects..."
///     }
///
///     // 4. Optional: Customize empty state text
///     override var emptyStateText: String {
///         if isLoading {
///             return loadingStateText
///         }
///         return items.isEmpty ? "No projects yet" : ""
///     }
///
///     // 5. Convenience method for loading
///     func loadProjects() async {
///         await loadItems()
///     }
///
///     // 6. Convenience method for creating with domain-specific parameters
///     func createProject(name: String, path: String, defaultModel: String, description: String?) async -> Project? {
///         let request = CreateProjectRequest(
///             name: name,
///             path: path,
///             defaultModel: defaultModel,
///             description: description
///         )
///         return await createItem(body: request)
///     }
///
///     // 7. Convenience method for deleting
///     func deleteProject(_ project: Project) async {
///         await deleteItem(id: project.id)
///     }
/// }
/// ```
///
/// ## Available Operations
///
/// - **`loadItems()`**: Loads all items from the API endpoint
/// - **`retryLoad()`**: Retries loading items (useful for error recovery)
/// - **`createItem(body:)`**: Creates a new item with the provided request body
/// - **`updateItem(id:body:)`**: Updates an existing item
/// - **`deleteItem(id:)`**: Deletes an item by ID
///
/// ## Published Properties
///
/// - **`items`**: Array of items loaded from the API
/// - **`isLoading`**: Boolean indicating whether a load operation is in progress
/// - **`error`**: The most recent error, if any
///
/// ## Requirements for Subclasses
///
/// - Must override `resourcePath` to return the API endpoint (e.g., "/projects", "/sessions")
/// - Item type must conform to both `Decodable` and `Identifiable`
/// - Item type must match the API response structure
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
