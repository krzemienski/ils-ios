import Foundation
import Observation
import ILSShared

@MainActor
@Observable
class MCPMarketplaceViewModel {
    var featuredEntries: [MCPMarketplaceEntry] = []
    var isLoadingFeatured = false
    var error: Error?
    var selectedCategory: String = "All"

    private var client: APIClient?

    init() {}

    func configure(client: APIClient) {
        self.client = client
    }

    /// All categories derived from featuredEntries, always starting with "All"
    var categories: [String] {
        var cats = Set<String>()
        for entry in featuredEntries {
            if !entry.category.isEmpty {
                cats.insert(entry.category)
            }
        }
        return ["All"] + cats.sorted()
    }

    /// Featured entries filtered by selected category
    var filteredEntries: [MCPMarketplaceEntry] {
        if selectedCategory == "All" {
            return featuredEntries
        }
        return featuredEntries.filter { $0.category == selectedCategory }
    }

    /// Load the curated marketplace catalog from the backend
    func loadFeatured() async {
        guard let client else { return }
        isLoadingFeatured = true
        error = nil

        do {
            let response: APIResponse<ListResponse<MCPMarketplaceEntry>> = try await client.get("/mcp/marketplace")
            if let data = response.data {
                featuredEntries = data.items
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to load MCP marketplace: \(error.localizedDescription)", category: "mcp")
        }

        isLoadingFeatured = false
    }
}
