import Foundation

// MARK: - GitHub Code Search

/// Top-level response from the GitHub code-search API.
///
/// Maps to the JSON envelope returned by `GET https://api.github.com/search/code`.
public struct GitHubCodeSearchResponse: Codable, Sendable {
    /// Total number of code results matching the query, regardless of pagination.
    public let totalCount: Int
    /// Whether the result set is incomplete due to GitHub's search timeout or rate limits.
    public let incompleteResults: Bool
    /// The page of matching code items returned for this request.
    public let items: [GitHubCodeItem]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case incompleteResults = "incomplete_results"
        case items
    }
}

/// A single code file match returned by the GitHub code-search API.
public struct GitHubCodeItem: Codable, Sendable {
    /// Filename of the matching code file (e.g., `"README.md"`).
    public let name: String
    /// Repository-relative path to the matching file (e.g., `"src/utils/README.md"`).
    public let path: String
    /// URL to the file on GitHub.com for display in a browser.
    public let htmlUrl: String
    /// Metadata about the repository that contains this file.
    public let repository: GitHubRepository

    enum CodingKeys: String, CodingKey {
        case name, path
        case htmlUrl = "html_url"
        case repository
    }
}

/// Metadata for a GitHub repository as returned within a code-search result.
public struct GitHubRepository: Codable, Identifiable, Sendable {
    /// Unique numeric identifier assigned by GitHub to this repository.
    public let id: Int
    /// Fully qualified repository name in `"owner/repo"` format (e.g., `"apple/swift"`).
    public let fullName: String
    /// Optional human-readable description of the repository.
    public let description: String?
    /// Number of users who have starred this repository.
    public let stargazersCount: Int
    /// ISO 8601 timestamp of the most recent push or metadata update to this repository.
    public let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case description
        case stargazersCount = "stargazers_count"
        case updatedAt = "updated_at"
    }
}

// MARK: - Skill Search

/// A normalized skill search result derived from a GitHub repository.
///
/// Used to display skill candidates in the Discover tab before the user chooses to install one.
public struct GitHubSearchResult: Codable, Identifiable, Sendable {
    /// Stable client-side identifier for this result, used by SwiftUI list diffing.
    public let id: UUID
    /// Fully qualified repository name in `"owner/repo"` format.
    public let repository: String
    /// Display name of the skill or repository.
    public let name: String
    /// Optional description of what the skill does.
    public let description: String?
    /// Number of GitHub stars the repository has received.
    public let stars: Int
    /// ISO 8601 or human-readable timestamp of the last repository update.
    public let lastUpdated: String?
    /// Repository-relative path to the skill directory, if the skill lives in a subdirectory.
    public let skillPath: String?

    /// Creates a new GitHub search result.
    /// - Parameters:
    ///   - id: Stable identifier for SwiftUI list diffing (default: new `UUID()`).
    ///   - repository: Fully qualified repository name in `"owner/repo"` format.
    ///   - name: Display name of the skill or repository.
    ///   - description: Optional description of the skill.
    ///   - stars: Number of GitHub stars (default: `0`).
    ///   - lastUpdated: Optional timestamp of the last repository update.
    ///   - skillPath: Optional repository-relative path to the skill subdirectory.
    public init(id: UUID = UUID(), repository: String, name: String, description: String? = nil, stars: Int = 0, lastUpdated: String? = nil, skillPath: String? = nil) {
        self.id = id
        self.repository = repository
        self.name = name
        self.description = description
        self.stars = stars
        self.lastUpdated = lastUpdated
        self.skillPath = skillPath
    }
}

/// Request payload for installing a skill from a GitHub repository.
public struct SkillInstallRequest: Codable, Sendable {
    /// Fully qualified repository name in `"owner/repo"` format that contains the skill.
    public let repository: String
    /// Repository-relative path to the skill directory, if the skill lives in a subdirectory.
    /// `nil` indicates the skill is at the repository root.
    public let skillPath: String?

    /// Creates a new skill install request.
    /// - Parameters:
    ///   - repository: Fully qualified repository name in `"owner/repo"` format.
    ///   - skillPath: Optional repository-relative path to the skill subdirectory.
    public init(repository: String, skillPath: String? = nil) {
        self.repository = repository
        self.skillPath = skillPath
    }
}

// MARK: - Plugin Search

/// A normalized plugin search result sourced from a marketplace repository.
///
/// Used to display plugin candidates in the Discover tab before the user chooses to install one.
public struct PluginSearchResult: Codable, Identifiable, Sendable {
    /// Stable client-side identifier for this result, used by SwiftUI list diffing.
    public let id: UUID
    /// Display name of the plugin.
    public let name: String
    /// Optional description of what the plugin does.
    public let description: String?
    /// Number of GitHub stars the plugin's repository has received, if available.
    public let stars: Int?
    /// Source provider for this plugin (e.g., `"github"`).
    public let source: String
    /// Identifier of the marketplace registry this plugin was discovered in.
    public let marketplace: String
    /// Whether this plugin is already installed in the current session.
    public let isInstalled: Bool

    /// Creates a new plugin search result.
    /// - Parameters:
    ///   - id: Stable identifier for SwiftUI list diffing (default: new `UUID()`).
    ///   - name: Display name of the plugin.
    ///   - description: Optional description of the plugin.
    ///   - stars: Optional GitHub star count for the plugin's repository.
    ///   - source: Source provider identifier (e.g., `"github"`).
    ///   - marketplace: Identifier of the marketplace registry the plugin belongs to.
    ///   - isInstalled: Whether the plugin is currently installed (default: `false`).
    public init(id: UUID = UUID(), name: String, description: String? = nil, stars: Int? = nil, source: String, marketplace: String, isInstalled: Bool = false) {
        self.id = id
        self.name = name
        self.description = description
        self.stars = stars
        self.source = source
        self.marketplace = marketplace
        self.isInstalled = isInstalled
    }
}

// MARK: - Marketplace

/// Request payload for adding a new marketplace repository to the ILS backend.
public struct AddMarketplaceRequest: Codable, Sendable {
    /// Source provider for the marketplace (e.g., `"github"`).
    public let source: String
    /// Fully qualified repository name in `"owner/repo"` format that acts as the marketplace index.
    public let repo: String

    /// Creates a new add-marketplace request.
    /// - Parameters:
    ///   - source: Source provider identifier (default: `"github"`).
    ///   - repo: Fully qualified repository name in `"owner/repo"` format.
    public init(source: String = "github", repo: String) {
        self.source = source
        self.repo = repo
    }
}

/// A registered marketplace that ILS queries for discoverable plugins.
public struct Marketplace: Codable, Identifiable, Sendable {
    /// Unique identifier for this marketplace registration.
    public let id: UUID
    /// Human-readable display name of the marketplace.
    public let name: String
    /// Source provider for this marketplace (e.g., `"github"`).
    public let source: String
    /// Fully qualified repository name in `"owner/repo"` format that acts as the marketplace index.
    public let repo: String
    /// Plugins discovered within this marketplace, populated after fetching the index.
    public var plugins: [PluginInfo]?

    /// Creates a new marketplace.
    /// - Parameters:
    ///   - id: Unique identifier for this marketplace (default: new `UUID()`).
    ///   - name: Human-readable display name.
    ///   - source: Source provider identifier (default: `"github"`).
    ///   - repo: Fully qualified repository name in `"owner/repo"` format.
    ///   - plugins: Optional initial list of plugins from this marketplace.
    public init(id: UUID = UUID(), name: String, source: String = "github", repo: String, plugins: [PluginInfo]? = nil) {
        self.id = id
        self.name = name
        self.source = source
        self.repo = repo
        self.plugins = plugins
    }
}

// MARK: - GitHub Repository Preview

/// Preview data for a GitHub repository, including README content and file tree.
///
/// Used by the Discover tab preview view before installing a skill or plugin.
public struct GitHubRepoPreview: Codable, Sendable {
    /// Fully qualified repository name in `"owner/repo"` format.
    public let repository: String
    /// Repository display name shown in the UI.
    public let name: String
    /// Optional description of the repository.
    public let description: String?
    /// Number of GitHub stars the repository has received.
    public let stars: Int
    /// Markdown content of the repository's README, truncated to 5 000 characters by the backend.
    public let readme: String?
    /// Root-level file and directory entries from the repository's contents listing.
    public let files: [GitHubFileEntry]
    /// ISO 8601 or human-readable timestamp of the last repository update.
    public let lastUpdated: String?

    /// Creates a new GitHub repository preview.
    /// - Parameters:
    ///   - repository: Fully qualified repository name in `"owner/repo"` format.
    ///   - name: Display name of the repository.
    ///   - description: Optional description of the repository.
    ///   - stars: Number of GitHub stars (default: `0`).
    ///   - readme: Optional markdown README content (truncated to 5 000 chars by the backend).
    ///   - files: Root-level file tree entries (default: empty array).
    ///   - lastUpdated: Optional timestamp of the last repository update.
    public init(repository: String, name: String, description: String? = nil,
                stars: Int = 0, readme: String? = nil, files: [GitHubFileEntry] = [],
                lastUpdated: String? = nil) {
        self.repository = repository
        self.name = name
        self.description = description
        self.stars = stars
        self.readme = readme
        self.files = files
        self.lastUpdated = lastUpdated
    }
}

/// A single file or directory entry from a GitHub repository's contents listing.
public struct GitHubFileEntry: Codable, Identifiable, Sendable {
    /// Stable client-side identifier for this entry, used by SwiftUI list diffing.
    public let id: UUID
    /// Filename or directory name (e.g., `"README.md"` or `"src"`).
    public let name: String
    /// Repository-relative path to this entry (e.g., `"src/utils/README.md"`).
    public let path: String
    /// Entry type: `"file"` for a regular file or `"dir"` for a directory.
    public let type: String
    /// File size in bytes, or `nil` for directory entries.
    public let size: Int?

    /// Creates a new GitHub file entry.
    /// - Parameters:
    ///   - id: Stable identifier for SwiftUI list diffing (default: new `UUID()`).
    ///   - name: Filename or directory name.
    ///   - path: Repository-relative path to this entry.
    ///   - type: Entry type — `"file"` for a regular file or `"dir"` for a directory.
    ///   - size: File size in bytes (default: `nil`; not applicable to directories).
    public init(id: UUID = UUID(), name: String, path: String, type: String, size: Int? = nil) {
        self.id = id
        self.name = name
        self.path = path
        self.type = type
        self.size = size
    }
}

/// Describes a required environment variable for an MCP server.
public struct MCPEnvVarSpec: Codable, Identifiable, Sendable {
    public let id: UUID
    public let key: String
    public let description: String
    public let isRequired: Bool
    public let placeholder: String?

    public init(id: UUID = UUID(), key: String, description: String, isRequired: Bool = true, placeholder: String? = nil) {
        self.id = id
        self.key = key
        self.description = description
        self.isRequired = isRequired
        self.placeholder = placeholder
    }
}

/// Represents a curated MCP server entry in the marketplace.
public struct MCPMarketplaceEntry: Codable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let repository: String
    public let command: String
    public let args: [String]
    public let requiredEnvVars: [MCPEnvVarSpec]
    public let category: String
    public let stars: Int
    public let isStaffPick: Bool
    public let isTrending: Bool
    public let tags: [String]
    public let description: String?

    public init(
        id: UUID = UUID(),
        name: String,
        repository: String,
        command: String,
        args: [String] = [],
        requiredEnvVars: [MCPEnvVarSpec] = [],
        category: String,
        stars: Int = 0,
        isStaffPick: Bool = false,
        isTrending: Bool = false,
        tags: [String] = [],
        description: String? = nil
    ) {
        self.id = id
        self.name = name
        self.repository = repository
        self.command = command
        self.args = args
        self.requiredEnvVars = requiredEnvVars
        self.category = category
        self.stars = stars
        self.isStaffPick = isStaffPick
        self.isTrending = isTrending
        self.tags = tags
        self.description = description
    }
}
