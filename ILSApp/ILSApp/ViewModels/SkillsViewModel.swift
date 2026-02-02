import Foundation
import ILSShared

@MainActor
class SkillsViewModel: ObservableObject {
    @Published var skills: [SkillItem] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var searchText = ""

    private let client = APIClient()

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

    /// Empty state text for UI display
    var emptyStateText: String {
        if isLoading {
            return "Loading skills..."
        }
        if !searchText.isEmpty && filteredSkills.isEmpty {
            return "No skills found"
        }
        return skills.isEmpty ? "No skills found" : ""
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
                skills = data.items
            }
        } catch {
            self.error = error
            print("❌ Failed to load skills: \(error.localizedDescription)")
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
        do {
            let request = CreateSkillRequest(
                name: name,
                description: description,
                content: content
            )
            let response: APIResponse<SkillItem> = try await client.post("/skills", body: request)
            if let skill = response.data {
                skills.append(skill)
                return skill
            }
        } catch {
            self.error = error
            print("❌ Failed to create skill '\(name)': \(error.localizedDescription)")
        }
        return nil
    }

    func updateSkill(_ skill: SkillItem, content: String) async -> SkillItem? {
        do {
            let request = UpdateSkillRequest(content: content)
            let response: APIResponse<SkillItem> = try await client.put("/skills/\(skill.name)", body: request)
            if let updated = response.data {
                if let index = skills.firstIndex(where: { $0.id == skill.id }) {
                    skills[index] = updated
                }
                return updated
            }
        } catch {
            self.error = error
            print("❌ Failed to update skill '\(skill.name)': \(error.localizedDescription)")
        }
        return nil
    }

    func deleteSkill(_ skill: SkillItem) async {
        do {
            let _: APIResponse<DeletedResponse> = try await client.delete("/skills/\(skill.name)")
            skills.removeAll { $0.id == skill.id }
        } catch {
            self.error = error
            print("❌ Failed to delete skill '\(skill.name)': \(error.localizedDescription)")
        }
    }
}
