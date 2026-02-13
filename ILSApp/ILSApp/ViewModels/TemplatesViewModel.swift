import Foundation
import ILSShared
import CloudKit

@MainActor
class TemplatesViewModel: ObservableObject {
    @Published var templates: [Template] = []
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
            return "Loading templates..."
        }
        return templates.isEmpty ? "No templates" : ""
    }

    func loadTemplates() async {
        isLoading = true
        error = nil

        do {
            // Load from CloudKit if sync is enabled, otherwise use API
            if isSyncEnabled, let cloudKitService {
                // Load from CloudKit
                let cloudTemplates = try await cloudKitService.fetchTemplates()
                templates = cloudTemplates.sorted { $0.modificationDate > $1.modificationDate }
            } else if let client {
                // Fallback to API
                let response: APIResponse<ListResponse<Template>> = try await client.get("/templates")
                if let data = response.data {
                    templates = data.items
                }
            }
        } catch {
            self.error = error
            print("❌ Failed to load templates: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func retryLoadTemplates() async {
        await loadTemplates()
    }

    func createTemplate(name: String, content: String, description: String?, category: String?) async -> Template? {
        let template = Template(
            name: name,
            content: content,
            description: description,
            category: category
        )

        do {
            // Save to CloudKit if sync is enabled
            if isSyncEnabled, let cloudKitService {
                _ = try await cloudKitService.saveTemplate(template)
                templates.insert(template, at: 0)
                return template
            } else if let client {
                // Fallback to API
                let request = CreateTemplateRequest(
                    name: name,
                    content: content,
                    description: description,
                    category: category
                )
                let response: APIResponse<Template> = try await client.post("/templates", body: request)
                if let newTemplate = response.data {
                    templates.insert(newTemplate, at: 0)
                    return newTemplate
                }
            }
        } catch {
            self.error = error
            print("❌ Failed to create template: \(error.localizedDescription)")
        }
        return nil
    }

    func updateTemplate(_ template: Template) async -> Bool {
        do {
            // Update in CloudKit if sync is enabled
            if isSyncEnabled, let cloudKitService {
                _ = try await cloudKitService.saveTemplate(template)
                // Update local list
                if let index = templates.firstIndex(where: { $0.id == template.id }) {
                    templates[index] = template
                }
                return true
            } else if let client {
                // Fallback to API
                let request = UpdateTemplateRequest(
                    name: template.name,
                    content: template.content,
                    description: template.description,
                    category: template.category
                )
                let response: APIResponse<Template> = try await client.put("/templates/\(template.id)", body: request)
                if let updated = response.data {
                    if let index = templates.firstIndex(where: { $0.id == template.id }) {
                        templates[index] = updated
                    }
                    return true
                }
            }
        } catch {
            self.error = error
            print("❌ Failed to update template: \(error.localizedDescription)")
        }
        return false
    }

    func deleteTemplate(_ template: Template) async {
        do {
            // Delete from CloudKit if sync is enabled
            if isSyncEnabled, let cloudKitService {
                try await cloudKitService.deleteTemplate(template.id)
            } else if let client {
                // Fallback to API
                let _: APIResponse<DeletedResponse> = try await client.delete("/templates/\(template.id)")
            }

            // Remove from local list
            templates.removeAll { $0.id == template.id }
        } catch {
            self.error = error
            print("❌ Failed to delete template: \(error.localizedDescription)")
        }
    }
}

// MARK: - Request Types

struct CreateTemplateRequest: Encodable {
    let name: String
    let content: String
    let description: String?
    let category: String?
}

struct UpdateTemplateRequest: Encodable {
    let name: String
    let content: String
    let description: String?
    let category: String?
}
