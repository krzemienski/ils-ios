import Foundation
import Vapor

/// Response structure for GitHub repository search
struct GitHubSearchResponse: Codable, Sendable {
    let items: [GitHubRepository]
    let totalCount: Int?

    enum CodingKeys: String, CodingKey {
        case items
        case totalCount = "total_count"
    }
}

/// GitHub repository information
public struct GitHubRepository: Content, Sendable {
    public let id: Int
    public let name: String
    public let fullName: String
    public let description: String?
    public let htmlUrl: String
    public let stargazersCount: Int
    public let language: String?
    public let updatedAt: String
    public let owner: GitHubOwner
    public let topics: [String]?

    enum CodingKeys: String, CodingKey {
        case id, name, description, language, topics, owner
        case fullName = "full_name"
        case htmlUrl = "html_url"
        case stargazersCount = "stargazers_count"
        case updatedAt = "updated_at"
    }
}

/// GitHub repository owner information
public struct GitHubOwner: Content, Sendable {
    public let login: String
    public let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case login
        case avatarUrl = "avatar_url"
    }
}

/// GitHub file content response
struct GitHubContentResponse: Codable {
    let name: String
    let path: String
    let content: String?
    let encoding: String?
    let size: Int
}

/// Cache entry with timestamp for TTL-based invalidation
private struct CacheEntry<T> {
    let value: T
    let timestamp: Date

    func isValid(ttl: TimeInterval) -> Bool {
        Date().timeIntervalSince(timestamp) < ttl
    }
}

/// Actor for thread-safe cache management
private actor GitHubCache {
    private var searchCache: [String: CacheEntry<GitHubSearchResponse>] = [:]
    private var contentCache: [String: CacheEntry<String>] = [:]
    private var repoCache: [String: CacheEntry<GitHubRepository>] = [:]

    /// Default TTL: 5 minutes for GitHub data
    private let defaultTTL: TimeInterval = 300

    func getCachedSearch(query: String, ttl: TimeInterval? = nil) -> GitHubSearchResponse? {
        guard let cache = searchCache[query], cache.isValid(ttl: ttl ?? defaultTTL) else {
            return nil
        }
        return cache.value
    }

    func setCachedSearch(query: String, response: GitHubSearchResponse) {
        searchCache[query] = CacheEntry(value: response, timestamp: Date())
    }

    func getCachedContent(key: String, ttl: TimeInterval? = nil) -> String? {
        guard let cache = contentCache[key], cache.isValid(ttl: ttl ?? defaultTTL) else {
            return nil
        }
        return cache.value
    }

    func setCachedContent(key: String, content: String) {
        contentCache[key] = CacheEntry(value: content, timestamp: Date())
    }

    func getCachedRepo(key: String, ttl: TimeInterval? = nil) -> GitHubRepository? {
        guard let cache = repoCache[key], cache.isValid(ttl: ttl ?? defaultTTL) else {
            return nil
        }
        return cache.value
    }

    func setCachedRepo(key: String, repo: GitHubRepository) {
        repoCache[key] = CacheEntry(value: repo, timestamp: Date())
    }

    func invalidateAll() {
        searchCache.removeAll()
        contentCache.removeAll()
        repoCache.removeAll()
    }
}

/// Shared cache instance
private let sharedCache = GitHubCache()

/// Service for GitHub API operations
struct GitHubService {
    private let baseURL = "https://api.github.com"
    private let session: URLSession

    /// Cache TTL in seconds (configurable)
    var cacheTTL: TimeInterval = 300

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Search

    /// Search GitHub for Claude Code skills
    /// - Parameter query: Search query string
    /// - Returns: Array of matching repositories
    func searchSkills(query: String) async throws -> [GitHubRepository] {
        // Check cache first
        if let cached = await sharedCache.getCachedSearch(query: query, ttl: cacheTTL) {
            return cached.items
        }

        // Build search query to find skills
        let searchQuery = "\(query) topic:claude-code-skill OR topic:claude-skill in:name,description,readme"
        guard let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw Abort(.badRequest, reason: "Invalid search query")
        }

        let urlString = "\(baseURL)/search/repositories?q=\(encodedQuery)&sort=stars&order=desc&per_page=30"
        guard let url = URL(string: urlString) else {
            throw Abort(.internalServerError, reason: "Failed to construct GitHub API URL")
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw Abort(.internalServerError, reason: "Invalid response from GitHub")
        }

        // Handle rate limiting
        if httpResponse.statusCode == 403 {
            if let rateLimitReset = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Reset"),
               let resetTime = TimeInterval(rateLimitReset) {
                let resetDate = Date(timeIntervalSince1970: resetTime)
                throw Abort(.tooManyRequests, reason: "GitHub API rate limit exceeded. Resets at \(resetDate)")
            }
            throw Abort(.forbidden, reason: "GitHub API access forbidden")
        }

        guard httpResponse.statusCode == 200 else {
            throw Abort(.badGateway, reason: "GitHub API returned status \(httpResponse.statusCode)")
        }

        let decoder = JSONDecoder()
        let searchResponse = try decoder.decode(GitHubSearchResponse.self, from: data)

        // Cache the response
        await sharedCache.setCachedSearch(query: query, response: searchResponse)

        return searchResponse.items
    }

    // MARK: - Repository Info

    /// Get repository information
    /// - Parameters:
    ///   - owner: Repository owner/organization
    ///   - repo: Repository name
    /// - Returns: Repository information
    func getRepoInfo(owner: String, repo: String) async throws -> GitHubRepository {
        let cacheKey = "\(owner)/\(repo)"

        // Check cache first
        if let cached = await sharedCache.getCachedRepo(key: cacheKey, ttl: cacheTTL) {
            return cached
        }

        let urlString = "\(baseURL)/repos/\(owner)/\(repo)"
        guard let url = URL(string: urlString) else {
            throw Abort(.internalServerError, reason: "Failed to construct GitHub API URL")
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw Abort(.internalServerError, reason: "Invalid response from GitHub")
        }

        if httpResponse.statusCode == 404 {
            throw Abort(.notFound, reason: "Repository \(owner)/\(repo) not found")
        }

        // Handle rate limiting
        if httpResponse.statusCode == 403 {
            if let rateLimitReset = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Reset"),
               let resetTime = TimeInterval(rateLimitReset) {
                let resetDate = Date(timeIntervalSince1970: resetTime)
                throw Abort(.tooManyRequests, reason: "GitHub API rate limit exceeded. Resets at \(resetDate)")
            }
            throw Abort(.forbidden, reason: "GitHub API access forbidden")
        }

        guard httpResponse.statusCode == 200 else {
            throw Abort(.badGateway, reason: "GitHub API returned status \(httpResponse.statusCode)")
        }

        let decoder = JSONDecoder()
        let repository = try decoder.decode(GitHubRepository.self, from: data)

        // Cache the response
        await sharedCache.setCachedRepo(key: cacheKey, repo: repository)

        return repository
    }

    // MARK: - Content Fetching

    /// Fetch SKILL.md content from a repository
    /// - Parameters:
    ///   - owner: Repository owner/organization
    ///   - repo: Repository name
    /// - Returns: Decoded SKILL.md content
    func fetchSkillContent(owner: String, repo: String) async throws -> String {
        let cacheKey = "\(owner)/\(repo)/SKILL.md"

        // Check cache first
        if let cached = await sharedCache.getCachedContent(key: cacheKey, ttl: cacheTTL) {
            return cached
        }

        // Try to fetch SKILL.md from common locations
        let possiblePaths = ["SKILL.md", "skill.md", "Skill.md"]

        for path in possiblePaths {
            do {
                let content = try await fetchFileContent(owner: owner, repo: repo, path: path)

                // Cache the response
                await sharedCache.setCachedContent(key: cacheKey, content: content)

                return content
            } catch {
                // Continue to next path
                continue
            }
        }

        throw Abort(.notFound, reason: "SKILL.md not found in repository \(owner)/\(repo)")
    }

    /// Fetch specific file content from repository
    /// - Parameters:
    ///   - owner: Repository owner/organization
    ///   - repo: Repository name
    ///   - path: File path in repository
    /// - Returns: Decoded file content
    private func fetchFileContent(owner: String, repo: String, path: String) async throws -> String {
        let urlString = "\(baseURL)/repos/\(owner)/\(repo)/contents/\(path)"
        guard let url = URL(string: urlString) else {
            throw Abort(.internalServerError, reason: "Failed to construct GitHub API URL")
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw Abort(.internalServerError, reason: "Invalid response from GitHub")
        }

        if httpResponse.statusCode == 404 {
            throw Abort(.notFound, reason: "File \(path) not found in \(owner)/\(repo)")
        }

        // Handle rate limiting
        if httpResponse.statusCode == 403 {
            if let rateLimitReset = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Reset"),
               let resetTime = TimeInterval(rateLimitReset) {
                let resetDate = Date(timeIntervalSince1970: resetTime)
                throw Abort(.tooManyRequests, reason: "GitHub API rate limit exceeded. Resets at \(resetDate)")
            }
            throw Abort(.forbidden, reason: "GitHub API access forbidden")
        }

        guard httpResponse.statusCode == 200 else {
            throw Abort(.badGateway, reason: "GitHub API returned status \(httpResponse.statusCode)")
        }

        let decoder = JSONDecoder()
        let contentResponse = try decoder.decode(GitHubContentResponse.self, from: data)

        // Decode base64 content
        guard let base64Content = contentResponse.content else {
            throw Abort(.internalServerError, reason: "No content returned from GitHub")
        }

        // Remove newlines and whitespace from base64 string
        let cleanedBase64 = base64Content.replacingOccurrences(of: "\n", with: "")

        guard let decodedData = Data(base64Encoded: cleanedBase64),
              let decodedString = String(data: decodedData, encoding: .utf8) else {
            throw Abort(.internalServerError, reason: "Failed to decode file content")
        }

        return decodedString
    }

    // MARK: - Cache Management

    /// Invalidate all caches
    func invalidateCache() async {
        await sharedCache.invalidateAll()
    }
}
