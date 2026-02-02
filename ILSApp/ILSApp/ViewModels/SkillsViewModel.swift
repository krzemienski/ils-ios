import Foundation
import ILSShared

@MainActor
class SkillsViewModel: ObservableObject {
    @Published var skills: [SkillItem] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let client = APIClient()

    func loadSkills() async {
        isLoading = true
        error = nil

        do {
            let response: APIResponse<ListResponse<SkillItem>> = try await client.get("/skills")
            if let data = response.data {
                skills = data.items
            }
        } catch {
            self.error = error
        }

        isLoading = false
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
        }
        return nil
    }

    func deleteSkill(_ skill: SkillItem) async {
        do {
            let _: APIResponse<DeletedResponse> = try await client.delete("/skills/\(skill.name)")
            skills.removeAll { $0.id == skill.id }
        } catch {
            self.error = error
        }
    }
}
