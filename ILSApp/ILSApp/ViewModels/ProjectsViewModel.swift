import Foundation
import ILSShared

@MainActor
class ProjectsViewModel: BaseViewModel<Project> {
    /// Convenience accessor for projects
    var projects: [Project] {
        items
    }

    override var resourcePath: String {
        "/projects"
    }

    override var loadingStateText: String {
        "Loading projects..."
    }

    override var emptyStateText: String {
        if isLoading {
            return loadingStateText
        }
        return items.isEmpty ? "No projects yet" : ""
    }

    func loadProjects() async {
        await loadItems()
    }

    func retryLoadProjects() async {
        await retryLoad()
    }

    func createProject(name: String, path: String, defaultModel: String, description: String?) async -> Project? {
        let request = CreateProjectRequest(
            name: name,
            path: path,
            defaultModel: defaultModel,
            description: description
        )
        return await self.createItem(body: request)
    }

    func updateProject(_ project: Project, name: String?, defaultModel: String?, description: String?) async -> Project? {
        let request = UpdateProjectRequest(
            name: name,
            defaultModel: defaultModel,
            description: description
        )
        return await self.updateItem(id: project.id, body: request)
    }

    func deleteProject(_ project: Project) async {
        await self.deleteItem(id: project.id)
    }
}

// MARK: - Request Types

struct CreateProjectRequest: Encodable {
    let name: String
    let path: String
    let defaultModel: String
    let description: String?
}

struct UpdateProjectRequest: Encodable {
    let name: String?
    let defaultModel: String?
    let description: String?
}
