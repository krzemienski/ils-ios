import Foundation
import ILSShared
import CloudKit

@MainActor
class SnippetsViewModel: ObservableObject {
    @Published var snippets: [Snippet] = []
    @Published var isLoading = false
    @Published var error: Error?

    private var client: APIClient?
    private var cloudKitService: CloudKitService?

    init() {}

    func configure(client: APIClient, cloudKitService: CloudKitService? = nil) {
        self.client = client
        self.cloudKitService = cloudKitService
    }

    /// Check if iCloud sync is enabled
    private var isSyncEnabled: Bool {
        // Default to true if key doesn't exist (first launch)
        if UserDefaults.standard.object(forKey: "ils_icloud_sync_enabled_v2") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "ils_icloud_sync_enabled_v2")
    }

    /// Empty state text for UI display
    var emptyStateText: String {
        if isLoading {
            return "Loading snippets..."
        }
        return snippets.isEmpty ? "No snippets" : ""
    }

    func loadSnippets() async {
        isLoading = true
        error = nil

        do {
            // Load from CloudKit if sync is enabled, otherwise use API
            if isSyncEnabled, let cloudKitService {
                // Load from CloudKit
                let cloudSnippets = try await cloudKitService.fetchSnippets()
                snippets = cloudSnippets.sorted { $0.modificationDate > $1.modificationDate }
            } else if let client {
                // Fallback to API
                let response: APIResponse<ListResponse<Snippet>> = try await client.get("/snippets")
                if let data = response.data {
                    snippets = data.items
                }
            }
        } catch {
            self.error = error
            print("❌ Failed to load snippets: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func retryLoadSnippets() async {
        await loadSnippets()
    }

    func createSnippet(
        name: String,
        content: String,
        description: String? = nil,
        language: String? = nil,
        category: String? = nil
    ) async -> Snippet? {
        guard let client else { return nil }
        do {
            let request = CreateSnippetRequest(
                name: name,
                content: content,
                description: description,
                language: language,
                category: category
            )
            let response: APIResponse<Snippet> = try await client.post("/snippets", body: request)
            if let snippet = response.data {
                snippets.insert(snippet, at: 0)

                // Sync to CloudKit if enabled
                if isSyncEnabled, let cloudKitService {
                    Task {
                        do {
                            _ = try await cloudKitService.saveSnippet(snippet)
                        } catch {
                            print("❌ Failed to sync snippet to CloudKit: \(error.localizedDescription)")
                        }
                    }
                }

                return snippet
            }
        } catch {
            self.error = error
            print("❌ Failed to create snippet: \(error.localizedDescription)")
        }
        return nil
    }

    func deleteSnippet(_ snippet: Snippet) async {
        do {
            // Delete from CloudKit if sync is enabled
            if isSyncEnabled, let cloudKitService {
                try await cloudKitService.deleteSnippet(snippet.id)
            } else if let client {
                // Fallback to API
                let _: APIResponse<DeletedResponse> = try await client.delete("/snippets/\(snippet.id)")
            }

            // Remove from local list
            snippets.removeAll { $0.id == snippet.id }
        } catch {
            self.error = error
            print("❌ Failed to delete snippet: \(error.localizedDescription)")
        }
    }
}

// MARK: - Request Types

struct CreateSnippetRequest: Encodable {
    let name: String
    let content: String
    let description: String?
    let language: String?
    let category: String?
}

struct DeletedResponse: Decodable {
    let deleted: Bool
}
