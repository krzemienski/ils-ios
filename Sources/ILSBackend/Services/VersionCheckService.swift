import Vapor
import Fluent
import ILSShared
import Logging

/// Storage key for shared VersionCheckService instance
struct VersionCheckServiceKey: StorageKey {
    typealias Value = VersionCheckService
}

extension Application {
    var versionCheckService: VersionCheckService {
        get {
            if let existing = self.storage[VersionCheckServiceKey.self] {
                return existing
            }
            let service = VersionCheckService(client: self.client, database: self.db)
            self.storage[VersionCheckServiceKey.self] = service
            return service
        }
        set {
            self.storage[VersionCheckServiceKey.self] = newValue
        }
    }
}

/// Service for checking GitHub releases for Claude Code CLI updates
struct VersionCheckService: Sendable {
    /// Structured logger for version checking operations
    private static let logger = Logger(label: "ils.version-check")

    /// GitHub repository owner for Claude Code CLI
    private static let repoOwner = "anthropics"

    /// GitHub repository name for Claude Code CLI
    private static let repoName = "claude-code"

    let client: Vapor.Client
    let token: String?
    let database: Database

    init(client: Vapor.Client, database: Database) {
        self.client = client
        self.token = Environment.get("GITHUB_TOKEN")
        self.database = database
    }

    /// Fetch the latest release information from GitHub
    func fetchLatestRelease() async throws -> GitHubRelease {
        let uri = URI(string: "https://api.github.com/repos/\(Self.repoOwner)/\(Self.repoName)/releases/latest")

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
                throw Abort(.tooManyRequests, reason: "GitHub API rate limit reached. Set GITHUB_TOKEN on host to increase limits.")
            }
            throw Abort(.badGateway, reason: "GitHub API returned \(response.status)")
        }

        let release = try response.content.decode(GitHubRelease.self)
        return release
    }

    /// Fetch all releases from GitHub (paginated)
    func fetchReleases(page: Int = 1, perPage: Int = 10) async throws -> [GitHubRelease] {
        let uri = URI(string: "https://api.github.com/repos/\(Self.repoOwner)/\(Self.repoName)/releases?page=\(page)&per_page=\(perPage)")

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
                throw Abort(.tooManyRequests, reason: "GitHub API rate limit reached. Set GITHUB_TOKEN on host to increase limits.")
            }
            throw Abort(.badGateway, reason: "GitHub API returned \(response.status)")
        }

        let releases = try response.content.decode([GitHubRelease].self)
        return releases
    }

    /// Check for updates comparing current version with latest release
    func checkForUpdates(currentVersion: String) async throws -> UpdateCheckResponse {
        let release = try await fetchLatestRelease()

        // Parse version from tag_name (remove 'v' prefix if present)
        let latestVersion = release.tagName.hasPrefix("v")
            ? String(release.tagName.dropFirst())
            : release.tagName

        // Compare versions
        let updateAvailable = isNewerVersion(latest: latestVersion, current: currentVersion)

        // Detect breaking changes in release notes
        let hasBreakingChanges = detectBreakingChanges(in: release.body)

        return UpdateCheckResponse(
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            updateAvailable: updateAvailable,
            changelog: release.body,
            releaseUrl: release.htmlUrl,
            hasBreakingChanges: hasBreakingChanges,
            releasedAt: release.publishedAt,
            checkedAt: Date()
        )
    }

    /// Compare semantic versions to determine if latest is newer than current
    private func isNewerVersion(latest: String, current: String) -> Bool {
        let latestComponents = parseSemanticVersion(latest)
        let currentComponents = parseSemanticVersion(current)

        // Compare major.minor.patch
        if latestComponents.0 > currentComponents.0 { return true }
        if latestComponents.0 < currentComponents.0 { return false }

        if latestComponents.1 > currentComponents.1 { return true }
        if latestComponents.1 < currentComponents.1 { return false }

        if latestComponents.2 > currentComponents.2 { return true }

        return false
    }

    /// Parse semantic version string into (major, minor, patch) tuple
    private func parseSemanticVersion(_ version: String) -> (Int, Int, Int) {
        let components = version.split(separator: ".").compactMap { Int($0) }

        let major = components.count > 0 ? components[0] : 0
        let minor = components.count > 1 ? components[1] : 0
        let patch = components.count > 2 ? components[2] : 0

        return (major, minor, patch)
    }

    /// Detect breaking changes in changelog/release notes
    private func detectBreakingChanges(in changelog: String?) -> Bool {
        guard let changelog = changelog?.lowercased() else {
            return false
        }

        // Keywords that indicate breaking changes
        let breakingKeywords = [
            "breaking change",
            "breaking:",
            "!:",
            "⚠️",
            "breaking api",
            "incompatible",
            "migration required"
        ]

        return breakingKeywords.contains { changelog.contains($0) }
    }
}

// MARK: - GitHub API Models

/// GitHub release information from API
struct GitHubRelease: Codable, Sendable {
    /// Release ID
    let id: Int

    /// Tag name (e.g., "v1.2.3")
    let tagName: String

    /// Release name/title
    let name: String?

    /// Release notes/changelog
    let body: String?

    /// Whether this is a draft release
    let draft: Bool

    /// Whether this is a prerelease
    let prerelease: Bool

    /// Timestamp when release was created
    let createdAt: Date

    /// Timestamp when release was published
    let publishedAt: Date?

    /// URL to the release page
    let htmlUrl: String

    /// Assets attached to the release
    let assets: [GitHubReleaseAsset]?

    enum CodingKeys: String, CodingKey {
        case id
        case tagName = "tag_name"
        case name
        case body
        case draft
        case prerelease
        case createdAt = "created_at"
        case publishedAt = "published_at"
        case htmlUrl = "html_url"
        case assets
    }
}

/// GitHub release asset information
struct GitHubReleaseAsset: Codable, Sendable {
    /// Asset ID
    let id: Int

    /// Asset name
    let name: String

    /// Content type
    let contentType: String

    /// File size in bytes
    let size: Int

    /// Download URL
    let browserDownloadUrl: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case contentType = "content_type"
        case size
        case browserDownloadUrl = "browser_download_url"
    }
}
