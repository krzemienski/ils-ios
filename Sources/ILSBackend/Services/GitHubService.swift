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

    /// Fetch the latest release tag for a GitHub repository.
    /// Returns the tag name (e.g., "v1.2.3" or "1.2.3"), or nil if no releases found.
    func getLatestRelease(owner: String, repo: String) async -> String? {
        let uri = URI(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")

        var headers = HTTPHeaders()
        headers.add(name: .accept, value: "application/vnd.github.v3+json")
        headers.add(name: .userAgent, value: "ILS-Backend/1.0")
        if let token = token {
            headers.add(name: .authorization, value: "Bearer \(token)")
        }

        do {
            let response = try await client.get(uri, headers: headers)
            guard response.status == .ok else {
                Self.logger.info("No releases found for \(owner)/\(repo): HTTP \(response.status)")
                return nil
            }

            struct ReleaseInfo: Codable {
                let tagName: String
                enum CodingKeys: String, CodingKey {
                    case tagName = "tag_name"
                }
            }

            let release = try response.content.decode(ReleaseInfo.self)
            return release.tagName
        } catch {
            Self.logger.warning("Failed to fetch latest release for \(owner)/\(repo): \(error)")
            return nil
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

    /// Fetch the README content for a repository using GitHub's README API.
    /// Uses GET /repos/{owner}/{repo}/readme which automatically finds the README
    /// regardless of filename casing (README.md, readme.md, README.rst, etc.).
    /// Returns nil if no README exists. Truncates content to 5000 characters for mobile.
    func fetchReadme(owner: String, repo: String) async -> String? {
        let uri = URI(string: "https://api.github.com/repos/\(owner)/\(repo)/readme")

        var headers = HTTPHeaders()
        headers.add(name: .accept, value: "application/vnd.github.v3+json")
        headers.add(name: .userAgent, value: "ILS-Backend/1.0")
        if let token = token {
            headers.add(name: .authorization, value: "Bearer \(token)")
        }

        do {
            let response = try await client.get(uri, headers: headers)
            guard response.status == .ok else {
                Self.logger.info("No README found for \(owner)/\(repo): HTTP \(response.status)")
                return nil
            }

            // GitHub returns base64-encoded content
            struct ReadmeResponse: Codable {
                let content: String?
                let encoding: String?
            }

            let readmeInfo = try response.content.decode(ReadmeResponse.self)
            guard let base64Content = readmeInfo.content,
                  readmeInfo.encoding == "base64" else {
                Self.logger.warning("README for \(owner)/\(repo) has unexpected encoding")
                return nil
            }

            // Remove newlines from base64 (GitHub splits into lines)
            let cleanBase64 = base64Content.replacingOccurrences(of: "\n", with: "")
            guard let data = Data(base64Encoded: cleanBase64),
                  let decoded = String(data: data, encoding: .utf8) else {
                Self.logger.warning("Failed to decode README base64 for \(owner)/\(repo)")
                return nil
            }

            // Truncate to 5000 chars for mobile rendering performance
            if decoded.count > 5000 {
                return String(decoded.prefix(5000)) + "\n\n---\n*README truncated. View full version on GitHub.*"
            }
            return decoded
        } catch {
            Self.logger.warning("Failed to fetch README for \(owner)/\(repo): \(error)")
            return nil
        }
    }

    /// Fetch the file listing for a repository directory using GitHub Contents API.
    /// Returns an array of GitHubFileEntry objects representing files and directories.
    /// Only fetches the root level (path = "") by default to avoid excessive API calls.
    func fetchRepoContents(owner: String, repo: String, path: String = "") async -> [GitHubFileEntry] {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let uri = URI(string: "https://api.github.com/repos/\(owner)/\(repo)/contents/\(encodedPath)")

        var headers = HTTPHeaders()
        headers.add(name: .accept, value: "application/vnd.github.v3+json")
        headers.add(name: .userAgent, value: "ILS-Backend/1.0")
        if let token = token {
            headers.add(name: .authorization, value: "Bearer \(token)")
        }

        do {
            let response = try await client.get(uri, headers: headers)
            guard response.status == .ok else {
                Self.logger.info("Failed to fetch contents for \(owner)/\(repo)/\(path): HTTP \(response.status)")
                return []
            }

            struct GitHubContentItem: Codable {
                let name: String
                let path: String
                let type: String    // "file" or "dir"
                let size: Int?
            }

            let items = try response.content.decode([GitHubContentItem].self)
            return items.map { item in
                GitHubFileEntry(
                    name: item.name,
                    path: item.path,
                    type: item.type,
                    size: item.size
                )
            }
        } catch {
            Self.logger.warning("Failed to fetch repo contents for \(owner)/\(repo)/\(path): \(error)")
            return []
        }
    }
}
