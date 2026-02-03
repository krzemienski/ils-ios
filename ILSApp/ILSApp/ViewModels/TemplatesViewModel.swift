import Foundation
import ILSShared

@MainActor
class TemplatesViewModel: ObservableObject {
    @Published var templates: [SessionTemplate] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var searchQuery: String = ""

    private let client = APIClient()

    /// Filtered templates based on search query
    var filteredTemplates: [SessionTemplate] {
        if searchQuery.isEmpty {
            return templates
        }
        return templates.filter { template in
            template.name.localizedCaseInsensitiveContains(searchQuery) ||
            template.description?.localizedCaseInsensitiveContains(searchQuery) == true ||
            template.tags.contains { $0.localizedCaseInsensitiveContains(searchQuery) }
        }
    }

    /// Favorite templates from filtered list
    var favoriteTemplates: [SessionTemplate] {
        filteredTemplates.filter { $0.isFavorite }
    }

    /// Non-favorite templates from filtered list
    var regularTemplates: [SessionTemplate] {
        filteredTemplates.filter { !$0.isFavorite }
    }

    /// Empty state text for UI display
    var emptyStateText: String {
        if isLoading {
            return "Loading templates..."
        }
        if !searchQuery.isEmpty && filteredTemplates.isEmpty {
            return "No templates found"
        }
        return templates.isEmpty ? "No templates" : ""
    }

    func loadTemplates() async {
        isLoading = true
        error = nil

        do {
            let response: APIResponse<ListResponse<SessionTemplate>> = try await client.get("/templates")
            if let data = response.data {
                templates = data.items
            }
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func retryLoadTemplates() async {
        await loadTemplates()
    }

    func createTemplate(
        name: String,
        description: String?,
        initialPrompt: String?,
        model: String?,
        permissionMode: PermissionMode?,
        tags: [String]?
    ) async -> SessionTemplate? {
        do {
            let request = CreateTemplateRequest(
                name: name,
                description: description,
                initialPrompt: initialPrompt,
                model: model,
                permissionMode: permissionMode,
                tags: tags
            )
            let response: APIResponse<SessionTemplate> = try await client.post("/templates", body: request)
            if let template = response.data {
                templates.insert(template, at: 0)
                return template
            }
        } catch {
            self.error = error
        }
        return nil
    }

    func updateTemplate(
        _ template: SessionTemplate,
        name: String?,
        description: String?,
        initialPrompt: String?,
        model: String?,
        permissionMode: PermissionMode?,
        tags: [String]?,
        isFavorite: Bool?
    ) async -> SessionTemplate? {
        do {
            let request = UpdateTemplateRequest(
                name: name,
                description: description,
                initialPrompt: initialPrompt,
                model: model,
                permissionMode: permissionMode,
                tags: tags,
                isFavorite: isFavorite
            )
            let response: APIResponse<SessionTemplate> = try await client.put("/templates/\(template.id)", body: request)
            if let updated = response.data {
                if let index = templates.firstIndex(where: { $0.id == template.id }) {
                    templates[index] = updated
                }
                return updated
            }
        } catch {
            self.error = error
        }
        return nil
    }

    func deleteTemplate(_ template: SessionTemplate) async {
        do {
            let _: APIResponse<DeletedResponse> = try await client.delete("/templates/\(template.id)")
            templates.removeAll { $0.id == template.id }
        } catch {
            self.error = error
        }
    }

    func toggleFavorite(_ template: SessionTemplate) async {
        do {
            let response: APIResponse<SessionTemplate> = try await client.post("/templates/\(template.id)/favorite", body: EmptyBody())
            if let updated = response.data {
                if let index = templates.firstIndex(where: { $0.id == template.id }) {
                    templates[index] = updated
                }
            }
        } catch {
            self.error = error
        }
    }

    func searchTemplates(_ query: String) {
        searchQuery = query
    }
}

// MARK: - Request Types

struct DeletedResponse: Decodable {
    let deleted: Bool
}

struct EmptyBody: Encodable {}
