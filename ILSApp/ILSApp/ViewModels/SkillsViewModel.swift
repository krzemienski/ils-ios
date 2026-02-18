import Foundation
import Observation
import ILSShared

@MainActor
@Observable
class SkillsViewModel {
    var skills: [Skill] = []
    var isLoading = false
    var error: Error?
    var searchText = ""
    var selectedScope: String = "all"
    var gitHubResults: [GitHubSearchResult] = []
    var isSearchingGitHub = false
    var gitHubSearchText = ""
    /// Track skills currently being toggled (enable/disable)
    var togglingSkills: Set<UUID> = []

    /// Update GitHub search text and trigger debounced search.
    /// Call this instead of assigning `gitHubSearchText` directly.
    /// For SwiftUI TextField bindings, call from `.onChange(of:)`.
    func updateGitHubSearchText(_ text: String) {
        gitHubSearchText = text
        debouncedGitHubSearch()
    }

    /// Trigger a debounced GitHub search based on current `gitHubSearchText`.
    private func debouncedGitHubSearch() {
        searchTask?.cancel()
        guard !gitHubSearchText.isEmpty else {
            gitHubResults = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            if !Task.isCancelled {
                await searchGitHub(query: gitHubSearchText)
            }
        }
    }

    private var client: APIClient?
    nonisolated(unsafe) private var searchTask: Task<Void, Never>?
    /// Precomputed lowercase search strings keyed by skill index, rebuilt when skills change
    private var searchCache: [(skill: Skill, searchText: String)] = []

    init() {}

    deinit {
        searchTask?.cancel()
    }

    func configure(client: APIClient) {
        self.client = client
    }

    /// Filtered skills based on search text using precomputed lowercase cache
    var filteredSkills: [Skill] {
        guard !searchText.isEmpty else { return skills }
        let query = searchText.lowercased()
        return searchCache
            .filter { $0.searchText.contains(query) }
            .map(\.skill)
    }

    /// Count of active skills in current dataset
    var activeCount: Int {
        skills.filter(\.isActive).count
    }

    /// Count of inactive skills in current dataset
    var inactiveCount: Int {
        skills.filter { !$0.isActive }.count
    }

    /// Rebuild the lowercase search cache when skills array changes
    private func rebuildSearchCache() {
        searchCache = skills.map { skill in
            let text = [
                skill.name.lowercased(),
                skill.description?.lowercased() ?? "",
                skill.tags.map { $0.lowercased() }.joined(separator: " ")
            ].joined(separator: " ")
            return (skill, text)
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
    /// - Parameters:
    ///   - refresh: If true, bypasses server cache to rescan ~/.claude directory
    ///   - scope: Filter by source scope (local, plugin, github, builtin). Nil or "all" returns all.
    func loadSkills(refresh: Bool = false, scope: String? = nil) async {
        guard let client else { return }
        isLoading = true
        error = nil

        do {
            var path = "/skills"
            var params: [String] = []
            if refresh { params.append("refresh=true") }
            if let scope, !scope.isEmpty, scope != "all" {
                params.append("scope=\(scope)")
            }
            if !params.isEmpty { path += "?" + params.joined(separator: "&") }

            let response: APIResponse<ListResponse<Skill>> = try await client.get(path)
            if let data = response.data {
                // Sort: active first, then alphabetical by name
                skills = data.items.sorted { lhs, rhs in
                    if lhs.isActive != rhs.isActive { return lhs.isActive }
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                rebuildSearchCache()
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to load skills: \(error.localizedDescription)", category: "skills")
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
                rebuildSearchCache()
                return skill
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to create skill '\(name)': \(error.localizedDescription)", category: "skills")
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
                    rebuildSearchCache()
                }
                return updated
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to update skill '\(skill.name)': \(error.localizedDescription)", category: "skills")
        }
        return nil
    }

    func deleteSkill(_ skill: Skill) async {
        guard let client else { return }
        do {
            let _: APIResponse<DeletedResponse> = try await client.delete("/skills/\(skill.name)")
            skills.removeAll { $0.id == skill.id }
            rebuildSearchCache()
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to delete skill '\(skill.name)': \(error.localizedDescription)", category: "skills")
        }
    }

    func toggleSkillActive(_ skill: Skill) async {
        guard let client else { return }
        togglingSkills.insert(skill.id)
        do {
            let endpoint = skill.isActive ? "/skills/\(skill.name)/disable" : "/skills/\(skill.name)/enable"
            let _: APIResponse<Skill> = try await client.post(endpoint, body: EmptyBody())
            // Reload to get updated state with current scope
            let scope = selectedScope == "all" ? nil : selectedScope
            await loadSkills(refresh: true, scope: scope)
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to toggle skill '\(skill.name)': \(error.localizedDescription)", category: "skills")
        }
        togglingSkills.remove(skill.id)
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
            AppLogger.shared.error("GitHub search failed: \(error.localizedDescription)", category: "skills")
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
            AppLogger.shared.error("Failed to install skill from GitHub: \(error.localizedDescription)", category: "skills")
            return false
        }
    }
}
