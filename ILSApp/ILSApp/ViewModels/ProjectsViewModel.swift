import Foundation
import ILSShared

@MainActor
class ProjectsViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var hasMore = true
    private var currentOffset = 0
    private let pageSize = 50

    private var client: APIClient?

    init() {}

    func configure(client: APIClient) {
        self.client = client
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

        do {
            let path = "/projects?limit=\(pageSize)&offset=\(currentOffset)" + (refresh ? "&refresh=true" : "")
            let response: APIResponse<ListResponse<Project>> = try await client.get(path)
            if let data = response.data {
                if currentOffset == 0 {
                    projects = data.items
                } else {
                    projects.append(contentsOf: data.items)
                }
                hasMore = data.items.count == pageSize
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to load projects: \(error.localizedDescription)")
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
            AppLogger.shared.error("Failed to create project: \(error.localizedDescription)")
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
            AppLogger.shared.error("Failed to update project: \(error.localizedDescription)")
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
            AppLogger.shared.error("Failed to delete project: \(error.localizedDescription)")
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
            AppLogger.shared.error("Failed to duplicate project: \(error.localizedDescription)")
        }
        return nil
    }
}
