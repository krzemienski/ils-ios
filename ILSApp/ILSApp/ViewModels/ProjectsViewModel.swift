import Foundation
import Observation
import ILSShared

@MainActor
@Observable
class ProjectsViewModel: BaseViewModel {
    var projects: [Project] = []
    var hasMore = true
    var searchText: String = ""
    private var currentOffset = 0
    private let pageSize = 50

    /// Projects filtered by the current search text (case-insensitive on name and path).
    var filteredProjects: [Project] {
        guard !searchText.isEmpty else { return projects }
        let query = searchText.lowercased()
        return projects.filter {
            $0.name.lowercased().contains(query) || $0.path.lowercased().contains(query)
        }
    }

    /// Empty state text for UI display
    var emptyStateText: String {
        if isLoading {
            return "Loading projects..."
        }
        return projects.isEmpty ? "No projects yet" : ""
    }

    func loadProjects(refresh: Bool = false) async {
        guard let client else { return }
        isLoading = true
        error = nil

        if refresh {
            currentOffset = 0
            hasMore = true
        }

        // Cache-first: show cached data immediately on first page load
        if currentOffset == 0 && projects.isEmpty {
            let cached = await CacheService.shared.getCachedProjects()
            if !cached.isEmpty {
                projects = cached
                AppLogger.shared.info("Loaded \(cached.count) projects from cache", category: "projects")
            }
        }

        do {
            let path = "/projects?limit=\(pageSize)&offset=\(currentOffset)" + (refresh ? "&refresh=true" : "")
            let response: APIResponse<ListResponse<Project>> = try await client.get(path)
            if let data = response.data {
                if currentOffset == 0 {
                    projects = data.items
                    // CONC-03: Use Task instead of Task.detached — CacheService actor handles isolation.
                    Task {
                        await CacheService.shared.cacheProjects(data.items)
                    }
                } else {
                    projects.append(contentsOf: data.items)
                }
                hasMore = data.items.count == pageSize
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to load projects: \(error.localizedDescription)", category: "projects")
        }

        isLoading = false
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }
        currentOffset += pageSize
        await loadProjects()
    }

    func retryLoadProjects() async {
        await loadProjects()
    }

    func createProject(name: String, path: String, defaultModel: String, description: String?) async -> Project? {
        guard let client else { return nil }
        do {
            let request = CreateProjectRequest(
                name: name,
                path: path,
                defaultModel: defaultModel,
                description: description
            )
            let response: APIResponse<Project> = try await client.post("/projects", body: request)
            if let project = response.data {
                projects.append(project)
                return project
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to create project: \(error.localizedDescription)", category: "projects")
        }
        return nil
    }

    func updateProject(_ project: Project, name: String?, defaultModel: String?, description: String?) async -> Project? {
        guard let client else { return nil }
        do {
            let request = UpdateProjectRequest(
                name: name,
                defaultModel: defaultModel,
                description: description
            )
            let response: APIResponse<Project> = try await client.put("/projects/\(project.id)", body: request)
            if let updated = response.data {
                if let index = projects.firstIndex(where: { $0.id == project.id }) {
                    projects[index] = updated
                }
                return updated
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to update project: \(error.localizedDescription)", category: "projects")
        }
        return nil
    }

    func deleteProject(_ project: Project) async {
        guard let client else { return }
        do {
            let _: APIResponse<DeletedResponse> = try await client.delete("/projects/\(project.id)")
            projects.removeAll { $0.id == project.id }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to delete project: \(error.localizedDescription)", category: "projects")
        }
    }

    func duplicateProject(_ project: Project) async -> Project? {
        guard let client else { return nil }
        do {
            let request = CreateProjectRequest(
                name: "\(project.name) (copy)",
                path: project.path,
                defaultModel: project.defaultModel,
                description: project.description
            )
            let response: APIResponse<Project> = try await client.post("/projects", body: request)
            if let newProject = response.data {
                projects.insert(newProject, at: 0)
                return newProject
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to duplicate project: \(error.localizedDescription)", category: "projects")
        }
        return nil
    }
}
