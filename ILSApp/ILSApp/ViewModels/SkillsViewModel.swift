import Foundation
import ILSShared

@MainActor
class SkillsViewModel: BaseViewModel<SkillItem> {
    @Published var searchText = ""

    /// Convenience accessor for skills
    var skills: [SkillItem] {
        items
    }

    override var resourcePath: String {
        "/skills"
    }

    override var loadingStateText: String {
        "Loading skills..."
    }

    override var emptyStateText: String {
        if isLoading {
            return loadingStateText
        }
        if !searchText.isEmpty && filteredSkills.isEmpty {
            return "No skills found"
        }
        return items.isEmpty ? "No skills found" : ""
    }

    /// Filtered skills based on search text (client-side filtering for responsiveness)
    var filteredSkills: [SkillItem] {
        guard !searchText.isEmpty else { return skills }
        let query = searchText.lowercased()
        return skills.filter { skill in
            skill.name.lowercased().contains(query) ||
            (skill.description?.lowercased().contains(query) ?? false) ||
            skill.tags.contains { $0.lowercased().contains(query) }
        }
    }

    /// Load skills from backend
    /// - Parameter refresh: If true, bypasses server cache to rescan ~/.claude directory
    func loadSkills(refresh: Bool = false) async {
        isLoading = true
        error = nil

        do {
            let path = refresh ? "/skills?refresh=true" : "/skills"
            let response: APIResponse<ListResponse<SkillItem>> = try await client.get(path)
            if let data = response.data {
                items = data.items
            }
        } catch {
            self.error = error
        }

        isLoading = false
    }

    /// Refresh skills by rescanning ~/.claude directory
    func refreshSkills() async {
        await loadSkills(refresh: true)
    }

    func retryLoadSkills() async {
        await loadSkills()
    }

    func createSkill(name: String, description: String?, content: String) async -> SkillItem? {
        let request = CreateSkillRequest(
            name: name,
            description: description,
            content: content
        )
        return await self.createItem(body: request)
    }

    func updateSkill(_ skill: SkillItem, content: String) async -> SkillItem? {
        // Skills API uses name as identifier, not id
        do {
            let request = UpdateSkillRequest(content: content)
            let response: APIResponse<SkillItem> = try await client.put("/skills/\(skill.name)", body: request)
            if let updated = response.data {
                if let index = items.firstIndex(where: { $0.id == skill.id }) {
                    items[index] = updated
                }
                return updated
            }
        } catch {
            self.error = error
        }
        return nil
    }

    func deleteSkill(_ skill: SkillItem) async {
        // Skills API uses name as identifier, not id
        do {
            let _: APIResponse<DeletedResponse> = try await client.delete("/skills/\(skill.name)")
            items.removeAll { $0.id == skill.id }
        } catch {
            self.error = error
        }
    }
}

// MARK: - Request Types

struct CreateSkillRequest: Encodable {
    let name: String
    let description: String?
    let content: String
}

struct UpdateSkillRequest: Encodable {
    let content: String
}
