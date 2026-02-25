import Vapor
import Fluent
import ILSShared
import Logging

/// Storage key for shared GitHubService instance
struct GitHubServiceKey: StorageKey {
    typealias Value = GitHubService
}

extension Application {
    var githubService: GitHubService {
        get {
            if let existing = self.storage[GitHubServiceKey.self] {
                return existing
            }
            let service = GitHubService(client: self.client, database: self.db)
            self.storage[GitHubServiceKey.self] = service
            return service
        }
        set {
            self.storage[GitHubServiceKey.self] = newValue
        }
    }
}

/// Service for searching GitHub for Claude Code skills and fetching content
struct GitHubService: Sendable {
    /// Structured logger for GitHub operations
    private static let logger = Logger(label: "ils.github")

    let client: Vapor.Client
    let token: String?
    let database: Database

    init(client: Vapor.Client, database: Database) {
        self.client = client
        self.token = Environment.get("GITHUB_TOKEN")
        self.database = database
    }

    /// Search GitHub Code API for SKILL.md files matching query
    func searchSkills(query: String, page: Int = 1, perPage: Int = 20) async throws -> [GitHubSearchResult] {
        // Check cache first
        let cacheKey = "skills:\(query):p\(page):pp\(perPage)"
        let indexingService = IndexingService(database: database)

        if let cachedJSON = try await indexingService.getCachedResults(query: cacheKey) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            do {
                let cached = try decoder.decode([GitHubSearchResult].self, from: Data(cachedJSON.utf8))
                return cached
            } catch {
                Self.logger.warning("Failed to decode cached GitHub search results: \(error)")
            }
        }

        let encodedQuery = "\(query)+filename:SKILL.md".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let uri = URI(string: "https://api.github.com/search/code?q=\(encodedQuery)&page=\(page)&per_page=\(perPage)")

        var headers = HTTPHeaders()
        headers.add(name: .accept, value: "application/vnd.github.v3+json")
        headers.add(name: .userAgent, value: "ILS-Backend/1.0")
        if let token = token {
            headers.add(name: .authorization, value: "Bearer \(token)")
        }

        let response = try await client.get(uri, headers: headers)

        // Check rate limit headers
        if let remaining = response.headers.first(name: "X-RateLimit-Remaining"),
           let remainingCount = Int(remaining),
           remainingCount < 10 {
            Self.logger.warning("GitHub API rate limit low: \(remainingCount) requests remaining")
        }

        guard response.status == .ok else {
            if response.status == .forbidden || response.status == .tooManyRequests {
                throw Abort(.tooManyRequests, reason: "GitHub search limit reached. Set GITHUB_TOKEN on host to increase limits.")
            }
            throw Abort(.badGateway, reason: "GitHub API returned \(response.status)")
        }

        let searchResponse = try response.content.decode(GitHubCodeSearchResponse.self)

        let results = searchResponse.items.map { item in
            GitHubSearchResult(
                repository: item.repository.fullName,
                name: item.name,
                description: item.repository.description,
                stars: item.repository.stargazersCount,
                lastUpdated: item.repository.updatedAt,
                skillPath: item.path
            )
        }

        // Cache the results
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let jsonData = try encoder.encode(results)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                try await indexingService.cacheSearchResults(query: cacheKey, results: jsonString)
            }
        } catch {
            Self.logger.warning("Failed to cache GitHub search results: \(error)")
        }

        return results
    }

    /// Search GitHub Code API for plugin.json files matching query
    func searchPlugins(query: String, page: Int = 1, perPage: Int = 20) async throws -> [GitHubSearchResult] {
        // Check cache first
        let cacheKey = "plugins:\(query):p\(page):pp\(perPage)"
        let indexingService = IndexingService(database: database)

        if let cachedJSON = try await indexingService.getCachedResults(query: cacheKey) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            do {
                let cached = try decoder.decode([GitHubSearchResult].self, from: Data(cachedJSON.utf8))
                return cached
            } catch {
                Self.logger.warning("Failed to decode cached GitHub plugin search results: \(error)")
            }
        }

        let encodedQuery = "\(query)+filename:plugin.json".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let uri = URI(string: "https://api.github.com/search/code?q=\(encodedQuery)&page=\(page)&per_page=\(perPage)")

        var headers = HTTPHeaders()
        headers.add(name: .accept, value: "application/vnd.github.v3+json")
        headers.add(name: .userAgent, value: "ILS-Backend/1.0")
        if let token = token {
            headers.add(name: .authorization, value: "Bearer \(token)")
        }

        let response = try await client.get(uri, headers: headers)

        // Check rate limit headers
        if let remaining = response.headers.first(name: "X-RateLimit-Remaining"),
           let remainingCount = Int(remaining),
           remainingCount < 10 {
            Self.logger.warning("GitHub API rate limit low: \(remainingCount) requests remaining")
        }

        guard response.status == .ok else {
            if response.status == .forbidden || response.status == .tooManyRequests {
                throw Abort(.tooManyRequests, reason: "GitHub search limit reached. Set GITHUB_TOKEN on host to increase limits.")
            }
            throw Abort(.badGateway, reason: "GitHub API returned \(response.status)")
        }

        let searchResponse = try response.content.decode(GitHubCodeSearchResponse.self)

        let results = searchResponse.items.map { item in
            GitHubSearchResult(
                repository: item.repository.fullName,
                name: item.name,
                description: item.repository.description,
                stars: item.repository.stargazersCount,
                lastUpdated: item.repository.updatedAt,
                skillPath: item.path
            )
        }

        // Cache the results
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let jsonData = try encoder.encode(results)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                try await indexingService.cacheSearchResults(query: cacheKey, results: jsonString)
            }
        } catch {
            Self.logger.warning("Failed to cache GitHub plugin search results: \(error)")
        }

        return results
    }

    /// Get the default branch for a GitHub repository (e.g. "main", "master", "develop").
    /// Falls back to "main" on any error.
    func getDefaultBranch(owner: String, repo: String) async -> String {
        struct RepoInfo: Codable {
            let defaultBranch: String

            enum CodingKeys: String, CodingKey {
                case defaultBranch = "default_branch"
            }
        }

        let uri = URI(string: "https://api.github.com/repos/\(owner)/\(repo)")

        var headers = HTTPHeaders()
        headers.add(name: .accept, value: "application/vnd.github.v3+json")
        headers.add(name: .userAgent, value: "ILS-Backend/1.0")
        if let token = token {
            headers.add(name: .authorization, value: "Bearer \(token)")
        }

        do {
            let response = try await client.get(uri, headers: headers)
            guard response.status == .ok else {
                Self.logger.warning("Failed to get default branch for \(owner)/\(repo): HTTP \(response.status)")
                return "main"
            }
            let repoInfo = try response.content.decode(RepoInfo.self)
            return repoInfo.defaultBranch
        } catch {
            Self.logger.warning("Failed to get default branch for \(owner)/\(repo): \(error)")
            return "main"
        }
    }

    /// Fetch raw file content from GitHub
    func fetchRawContent(owner: String, repo: String, path: String) async throws -> String {
        let branch = await getDefaultBranch(owner: owner, repo: repo)
        let uri = URI(string: "https://raw.githubusercontent.com/\(owner)/\(repo)/\(branch)/\(path)")

        var headers = HTTPHeaders()
        headers.add(name: .userAgent, value: "ILS-Backend/1.0")
        if let token = token {
            headers.add(name: .authorization, value: "Bearer \(token)")
        }

        let response = try await client.get(uri, headers: headers)

        // Check rate limit headers
        if let remaining = response.headers.first(name: "X-RateLimit-Remaining"),
           let remainingCount = Int(remaining),
           remainingCount < 10 {
            Self.logger.warning("GitHub API rate limit low: \(remainingCount) requests remaining")
        }

        guard response.status == .ok else {
            throw Abort(.notFound, reason: "Could not fetch file from GitHub")
        }

        guard let body = response.body, let content = body.getString(at: 0, length: body.readableBytes) else {
            throw Abort(.internalServerError, reason: "Empty response from GitHub")
        }

        return content
    }
}
