import Foundation

public struct GitHubCodeSearchResponse: Codable, Sendable {
    public let totalCount: Int
    public let incompleteResults: Bool
    public let items: [GitHubCodeItem]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case incompleteResults = "incomplete_results"
        case items
    }
}

public struct GitHubCodeItem: Codable, Sendable {
    public let name: String
    public let path: String
    public let htmlUrl: String
    public let repository: GitHubRepository

    enum CodingKeys: String, CodingKey {
        case name, path
        case htmlUrl = "html_url"
        case repository
    }
}

public struct GitHubRepository: Codable, Identifiable, Sendable {
    public let id: Int
    public let fullName: String
    public let description: String?
    public let stargazersCount: Int
    public let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case description
        case stargazersCount = "stargazers_count"
        case updatedAt = "updated_at"
    }
}

public struct GitHubSearchResult: Codable, Identifiable, Sendable {
    public let id: UUID
    public let repository: String
    public let name: String
    public let description: String?
    public let stars: Int
    public let lastUpdated: String?
    public let skillPath: String?

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

public struct SkillInstallRequest: Codable, Sendable {
    public let repository: String
    public let skillPath: String?

    public init(repository: String, skillPath: String? = nil) {
        self.repository = repository
        self.skillPath = skillPath
    }
}

public struct PluginSearchResult: Codable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let description: String?
    public let stars: Int?
    public let source: String
    public let marketplace: String
    public let isInstalled: Bool

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

public struct AddMarketplaceRequest: Codable, Sendable {
    public let source: String
    public let repo: String

    public init(source: String = "github", repo: String) {
        self.source = source
        self.repo = repo
    }
}

public struct Marketplace: Codable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let source: String
    public let repo: String
    public var plugins: [PluginInfo]?

    public init(id: UUID = UUID(), name: String, source: String = "github", repo: String, plugins: [PluginInfo]? = nil) {
        self.id = id
        self.name = name
        self.source = source
        self.repo = repo
        self.plugins = plugins
    }
}

/// Preview data for a GitHub repository, including README content and file tree.
/// Used by the Discover tab preview view before installing a skill or plugin.
public struct GitHubRepoPreview: Codable, Sendable {
    public let repository: String        // "owner/repo"
    public let name: String              // repo display name
    public let description: String?
    public let stars: Int
    public let readme: String?           // markdown content (truncated to 5000 chars by backend)
    public let files: [GitHubFileEntry]  // root-level file tree
    public let lastUpdated: String?

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
    public let id: UUID
    public let name: String
    public let path: String
    public let type: String    // "file" or "dir"
    public let size: Int?

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
