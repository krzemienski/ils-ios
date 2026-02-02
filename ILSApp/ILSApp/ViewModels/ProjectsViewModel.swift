import Foundation
import ILSShared

@MainActor
class ProjectsViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let client = APIClient()

    func loadProjects() async {
        isLoading = true
        error = nil

        do {
            let response: APIResponse<ListResponse<Project>> = try await client.get("/projects")
            if let data = response.data {
                projects = data.items
            }
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func createProject(name: String, path: String, defaultModel: String, description: String?) async -> Project? {
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
        }
        return nil
    }

    func updateProject(_ project: Project, name: String?, defaultModel: String?, description: String?) async -> Project? {
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
        }
        return nil
    }

    func deleteProject(_ project: Project) async {
        do {
            let _: APIResponse<DeletedResponse> = try await client.delete("/projects/\(project.id)")
            projects.removeAll { $0.id == project.id }
        } catch {
            self.error = error
        }
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
