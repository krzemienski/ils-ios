import Foundation
import Observation
import ILSShared

@MainActor
@Observable
class TemplatesViewModel {
    var templates: [SessionTemplate] = []
    var isLoading = false
    var error: Error?
    var searchText: String = ""

    private var client: APIClient?

    init() {}

    func configure(client: APIClient) {
        self.client = client
    }

    // MARK: - Computed Properties

    /// Templates that ship built-in with the app.
    var builtInTemplates: [SessionTemplate] {
        templates.filter { $0.isBuiltIn }
    }

    /// User-created templates.
    var userTemplates: [SessionTemplate] {
        templates.filter { !$0.isBuiltIn }
    }

    /// Templates filtered by the current search text (case-insensitive on name and description).
    var filteredTemplates: [SessionTemplate] {
        guard !searchText.isEmpty else { return templates }
        let query = searchText.lowercased()
        return templates.filter {
            $0.name.lowercased().contains(query) || $0.description.lowercased().contains(query)
        }
    }

    // MARK: - API Methods

    func loadTemplates() async {
        guard let client else { return }
        isLoading = true
        error = nil

        do {
            let response: APIResponse<ListResponse<SessionTemplate>> = try await client.get("/templates")
            if let data = response.data {
                templates = data.items
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to load templates: \(error.localizedDescription)", category: "templates")
        }

        isLoading = false
    }

    func createTemplate(request: CreateTemplateRequest) async -> SessionTemplate? {
        guard let client else { return nil }
        do {
            let response: APIResponse<SessionTemplate> = try await client.post("/templates", body: request)
            if let template = response.data {
                templates.append(template)
                return template
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to create template: \(error.localizedDescription)", category: "templates")
        }
        return nil
    }

    func updateTemplate(id: UUID, request: UpdateTemplateRequest) async -> SessionTemplate? {
        guard let client else { return nil }
        do {
            let response: APIResponse<SessionTemplate> = try await client.put("/templates/\(id)", body: request)
            if let updated = response.data {
                if let index = templates.firstIndex(where: { $0.id == id }) {
                    templates[index] = updated
                }
                return updated
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to update template: \(error.localizedDescription)", category: "templates")
        }
        return nil
    }

    func deleteTemplate(id: UUID) async {
        guard let client else { return }
        do {
            let _: APIResponse<DeletedResponse> = try await client.delete("/templates/\(id)")
            templates.removeAll { $0.id == id }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to delete template: \(error.localizedDescription)", category: "templates")
        }
    }

    func toggleFavorite(id: UUID) async {
        guard let client else { return }
        guard let existing = templates.first(where: { $0.id == id }) else { return }
        let request = UpdateTemplateRequest(isFavorite: !existing.isFavorite)
        _ = await updateTemplate(id: id, request: request)
    }
}
