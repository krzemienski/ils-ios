import Foundation
import ILSShared

@MainActor
class SkillsViewModel: ObservableObject {
    @Published var skills: [Skill] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var searchText = ""
    @Published var gitHubResults: [GitHubSearchResult] = []
    @Published var isSearchingGitHub = false
    @Published var gitHubSearchText = "" {
        didSet {
            // Debounce GitHub search with 300ms delay
            searchTask?.cancel()
            guard !gitHubSearchText.isEmpty else {
                gitHubResults = []
                return
            }
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                if !Task.isCancelled {
                    await searchGitHub(query: gitHubSearchText)
                }
            }
        }
    }

    private var client: APIClient?
    private var searchTask: Task<Void, Never>?

    init() {}

    func configure(client: APIClient) {
        self.client = client
    }

    /// Filtered skills based on search text (client-side filtering for responsiveness)
    var filteredSkills: [Skill] {
        guard !searchText.isEmpty else { return skills }
        let query = searchText.lowercased()
        return skills.filter { skill in
            let nameLower = skill.name.lowercased()
            let descLower = skill.description?.lowercased()
            return nameLower.contains(query) ||
                (descLower?.contains(query) ?? false) ||
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
        guard let client else { return }
        isLoading = true
        error = nil

        do {
            let path = refresh ? "/skills?refresh=true" : "/skills"
            let response: APIResponse<ListResponse<Skill>> = try await client.get(path)
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

    func createSkill(name: String, description: String?, content: String) async -> Skill? {
        guard let client else { return nil }
        do {
            let request = CreateSkillRequest(
                name: name,
                description: description,
                content: content
            )
            let response: APIResponse<Skill> = try await client.post("/skills", body: request)
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

    func updateSkill(_ skill: Skill, content: String) async -> Skill? {
        guard let client else { return nil }
        do {
            let request = UpdateSkillRequest(content: content)
            let response: APIResponse<Skill> = try await client.put("/skills/\(skill.name)", body: request)
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

    func deleteSkill(_ skill: Skill) async {
        guard let client else { return }
        do {
            let _: APIResponse<DeletedResponse> = try await client.delete("/skills/\(skill.name)")
            skills.removeAll { $0.id == skill.id }
        } catch {
            self.error = error
            print("❌ Failed to delete skill '\(skill.name)': \(error.localizedDescription)")
        }
    }

    func searchGitHub(query: String) async {
        guard let client, !query.isEmpty else {
            gitHubResults = []
            return
        }
        isSearchingGitHub = true
        error = nil
        do {
            let response: APIResponse<ListResponse<GitHubSearchResult>> = try await client.get("/skills/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)")
            if let data = response.data {
                gitHubResults = data.items
            }
        } catch {
            self.error = error
            print("❌ GitHub search failed: \(error.localizedDescription)")
        }
        isSearchingGitHub = false
    }

    func installFromGitHub(result: GitHubSearchResult) async -> Bool {
        guard let client else { return false }
        do {
            let request = SkillInstallRequest(repository: result.repository, skillPath: result.skillPath)
            let _: APIResponse<Skill> = try await client.post("/skills/install", body: request)
            // Reload skills to pick up the newly installed one
            await loadSkills(refresh: true)
            return true
        } catch {
            self.error = error
            print("❌ Failed to install skill from GitHub: \(error.localizedDescription)")
            return false
        }
    }
}
