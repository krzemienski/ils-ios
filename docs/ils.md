# ILS Application - Master Build Orchestration Specification

## System Directive

&lt;system_directive&gt;
You are an orchestration agent responsible for building the ILS (Intelligent Local Server) application. You MUST NOT proceed to any subsequent task until the current task's validation criteria are met with CONCRETE EVIDENCE. Evidence must include:
1. **For UI Tasks**: Screenshot from iOS Simulator showing the exact expected state
2. **For Backend Tasks**: Terminal output showing successful cURL response with expected JSON structure
3. **For Integration Tasks**: BOTH screenshot AND cURL output showing correlated data

**CRITICAL RULES:**
- NO task is complete without evidence artifact
- NO mocking, stubs, or placeholder data EVER
- NO proceeding on "it should work" - only proceed on "here is proof it works"
- EVERY compilation must succeed before ANY further work
- FAILED validation = STOP, diagnose, fix, re-validate
- Evidence must be timestamped and logged

**ORCHESTRATION PRINCIPLE:**
- Spawn sub-agents for parallelizable work ONLY when tasks have zero dependencies
- Sequential execution for ALL tasks with dependencies
- Gate checkpoints require ALL parallel tasks to complete with evidence before proceeding
  &lt;/system_directive&gt;

---

## Orchestration Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          PHASE 0: ENVIRONMENT SETUP                          │
│                              [SEQUENTIAL - BLOCKING]                         │
└─────────────────────────────────────────────────────────────────────────────┘
                                       │
                                       ▼
                              ┌─────────────────┐
                              │  GATE CHECK 0   │
                              │  Xcode + Swift  │
                              │  Environment OK │
                              └────────┬────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      PHASE 1: SHARED MODELS PACKAGE                          │
│                              [SEQUENTIAL - BLOCKING]                         │
└─────────────────────────────────────────────────────────────────────────────┘
                                       │
                                       ▼
                              ┌─────────────────┐
                              │  GATE CHECK 1   │
                              │ `swift build`   │
                              │   succeeds      │
                              └────────┬────────┘
                                       │
                    ┌──────────────────┴──────────────────┐
                    │                                      │
                    ▼                                      ▼
┌─────────────────────────────────┐    ┌─────────────────────────────────┐
│   PHASE 2A: VAPOR BACKEND       │    │   PHASE 2B: DESIGN SYSTEM       │
│   [SUB-AGENT ALPHA]             │    │   [SUB-AGENT BETA]              │
│   - Controllers                 │    │   - Theme tokens                │
│   - Routes                      │    │   - Color assets                │
│   - Services                    │    │   - Typography                  │
│   [PARALLEL TRACK]              │    │   [PARALLEL TRACK]              │
└───────────────┬─────────────────┘    └───────────────┬─────────────────┘
                │                                      │
                ▼                                      ▼
       ┌────────────────┐                     ┌────────────────┐
       │ GATE CHECK 2A  │                     │ GATE CHECK 2B  │
       │ cURL all       │                     │ Build succeeds │
       │ endpoints OK   │                     │ Preview renders│
       └────────┬───────┘                     └────────┬───────┘
                │                                      │
                └──────────────────┬───────────────────┘
                                   │
                                   ▼
                          ┌─────────────────┐
                          │  GATE CHECK 2   │
                          │  SYNC POINT     │
                          │ Both 2A+2B done │
                          └────────┬────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                     PHASE 3: iOS APP - VIEW BY VIEW                          │
│                         [SEQUENTIAL - STRICT ORDER]                          │
│                                                                              │
│   3.1 ServerConnectionView → 3.2 DashboardView → 3.3 SkillsListView →       │
│   3.4 SkillDetailView → 3.5 MCPServerListView → 3.6 PluginMarketplaceView → │
│   3.7 SettingsEditorView                                                     │
│                                                                              │
│   EACH VIEW: Code → Compile → Simulator Screenshot → THEN next view         │
└─────────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
                          ┌─────────────────┐
                          │  GATE CHECK 3   │
                          │ All 7 views     │
                          │ with screenshots│
                          └────────┬────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PHASE 4: INTEGRATION & REAL DATA                          │
│                              [SEQUENTIAL]                                    │
└─────────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
                          ┌─────────────────┐
                          │  GATE CHECK 4   │
                          │ Screenshot +    │
                          │ Backend logs    │
                          │ CORRELATED      │
                          └────────┬────────┘
                                   │
                                   ▼
                            ┌─────────────┐
                            │  COMPLETE   │
                            └─────────────┘
```

---

## PHASE 0: Environment Setup

&lt;phase_0&gt;

### Task 0.1: Create Project Directory Structure

**Sub-Agent Assignment:** MAIN AGENT (no delegation)

**Actions:**

```bash
mkdir -p ILSApp/Sources/{ILSShared/Models,ILSShared/DTOs,ILSBackend/App,ILSBackend/Controllers,ILSBackend/Services,ILSApp/Theme,ILSApp/Views,ILSApp/ViewModels,ILSApp/Services}
mkdir -p ILSApp/Tests
cd ILSApp
```

**Validation Criteria:**
- [ ] Run `tree ILSApp` and capture terminal output
- [ ] Output must show ALL directories listed above
- [ ] Evidence: Terminal screenshot showing tree output

**Evidence Required:**

```
EVIDENCE_0.1:
- Type: Terminal Output
- Command: `tree ILSApp -d`
- Expected: Directory tree matching specification
- Actual: [PASTE OUTPUT HERE]
- Status: PASS/FAIL
```

**BLOCKING:** Cannot proceed to 0.2 until PASS

---

### Task 0.2: Create Root Package.swift

**Sub-Agent Assignment:** MAIN AGENT

**Actions:**
Create `ILSApp/Package.swift`:

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ILSApp",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "ILSShared", targets: ["ILSShared"]),
        .executable(name: "ILSBackend", targets: ["ILSBackend"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.9.0"),
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.6.0"),
        .package(url: "https://github.com/orlandos-nl/Citadel.git", from: "0.7.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0")
    ],
    targets: [
        .target(
            name: "ILSShared",
            dependencies: ["Yams"],
            path: "Sources/ILSShared"
        ),
        .executableTarget(
            name: "ILSBackend",
            dependencies: [
                "ILSShared",
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver")
            ],
            path: "Sources/ILSBackend"
        )
    ]
)
```

**Validation Criteria:**
- [ ] Run `swift package resolve` - must complete without errors
- [ ] Run `swift package describe` - must show all targets
- [ ] Evidence: Terminal output of both commands

**Evidence Required:**

```
EVIDENCE_0.2:
- Type: Terminal Output
- Command 1: `swift package resolve`
- Expected 1: "Fetching..." followed by "Resolving..." with no errors
- Actual 1: [PASTE OUTPUT]
- Command 2: `swift package describe`
- Expected 2: Shows ILSShared and ILSBackend targets
- Actual 2: [PASTE OUTPUT]
- Status: PASS/FAIL
```

**BLOCKING:** Cannot proceed to Phase 1 until PASS

---

### Task 0.3: Create Xcode Workspace for iOS App

**Sub-Agent Assignment:** MAIN AGENT

**Actions:**
1. Open Xcode
2. Create new iOS App project named "ILSApp" inside the ILSApp directory
3. Configure:
   - Interface: SwiftUI
   - Language: Swift
   - Minimum deployment: iOS 17.0
4. Add local package dependency to ILSShared

**Validation Criteria:**
- [ ] Xcode project opens without errors
- [ ] Build succeeds (⌘+B) with zero errors
- [ ] Simulator launches showing default "Hello World" or similar
- [ ] Evidence: Screenshot of Xcode with successful build AND simulator showing app

**Evidence Required:**

```
EVIDENCE_0.3:
- Type: Screenshot
- Shows: Xcode build succeeded (green checkmark) + Simulator with app running
- Filename: evidence_0.3_xcode_setup.png
- Status: PASS/FAIL
```

**BLOCKING:** Cannot proceed to Phase 1 until PASS

&lt;/phase_0&gt;

---

## PHASE 1: Shared Models Package

&lt;phase_1&gt;

### Task 1.1: Create Base Model - ServerConnection.swift

**Sub-Agent Assignment:** MAIN AGENT

**File:** `Sources/ILSShared/Models/ServerConnection.swift`

```swift
import Foundation

public struct ServerConnection: Codable, Identifiable, Sendable {
    public let id: UUID
    public var host: String
    public var port: Int
    public var username: String
    public var authMethod: AuthMethod
    public var label: String?
    public var lastConnected: Date?
    
    public enum AuthMethod: String, Codable, Sendable {
        case password
        case sshKey
    }
    
    public init(
        id: UUID = UUID(),
        host: String,
        port: Int = 22,
        username: String,
        authMethod: AuthMethod,
        label: String? = nil,
        lastConnected: Date? = nil
    ) {
        self.id = id
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.label = label
        self.lastConnected = lastConnected
    }
}
```

**Validation Criteria:**
- [ ] Run `swift build --target ILSShared`
- [ ] Build must succeed with zero errors, zero warnings
- [ ] Evidence: Terminal output showing "Build complete!"

**Evidence Required:**

```
EVIDENCE_1.1:
- Type: Terminal Output
- Command: `swift build --target ILSShared`
- Expected: "Build complete!" with no errors
- Actual: [PASTE OUTPUT]
- Status: PASS/FAIL
```

**BLOCKING:** Cannot proceed to 1.2 until PASS

---

### Task 1.2: Create MCPServer.swift

**Sub-Agent Assignment:** MAIN AGENT

**File:** `Sources/ILSShared/Models/MCPServer.swift`

```swift
import Foundation

public struct MCPServer: Codable, Identifiable, Sendable {
    public var id: String { name }
    public let name: String
    public var command: String
    public var args: [String]
    public var env: [String: String]
    public var scope: ConfigScope
    public var status: ServerStatus?
    
    public enum ConfigScope: String, Codable, Sendable {
        case user
        case project
        case local
        case managed
    }
    
    public enum ServerStatus: String, Codable, Sendable {
        case healthy
        case error
        case unknown
    }
    
    public init(
        name: String,
        command: String,
        args: [String] = [],
        env: [String: String] = [:],
        scope: ConfigScope = .user,
        status: ServerStatus? = nil
    ) {
        self.name = name
        self.command = command
        self.args = args
        self.env = env
        self.scope = scope
        self.status = status
    }
}

// MARK: - MCP Configuration File Structure
public struct MCPConfiguration: Codable, Sendable {
    public var mcpServers: [String: MCPServerDefinition]
    
    public init(mcpServers: [String: MCPServerDefinition] = [:]) {
        self.mcpServers = mcpServers
    }
}

public struct MCPServerDefinition: Codable, Sendable {
    public var command: String
    public var args: [String]?
    public var env: [String: String]?
    
    public init(command: String, args: [String]? = nil, env: [String: String]? = nil) {
        self.command = command
        self.args = args
        self.env = env
    }
}
```

**Validation Criteria:**
- [ ] Run `swift build --target ILSShared`
- [ ] Build must succeed with zero errors
- [ ] Evidence: Terminal output

**Evidence Required:**

```
EVIDENCE_1.2:
- Type: Terminal Output
- Command: `swift build --target ILSShared`
- Expected: "Build complete!" 
- Actual: [PASTE OUTPUT]
- Status: PASS/FAIL
```

**BLOCKING:** Cannot proceed to 1.3 until PASS

---

### Task 1.3: Create Skill.swift with YAML Parsing

**Sub-Agent Assignment:** MAIN AGENT

**File:** `Sources/ILSShared/Models/Skill.swift`

```swift
import Foundation
import Yams

public struct Skill: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String
    public var version: String?
    public var isActive: Bool
    public var path: String
    public var rawContent: String
    public var source: SkillSource?
    
    public enum SkillSource: Codable, Sendable {
        case local
        case github(repository: String, stars: Int)
    }
    
    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        version: String? = nil,
        isActive: Bool = true,
        path: String,
        rawContent: String,
        source: SkillSource? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.version = version
        self.isActive = isActive
        self.path = path
        self.rawContent = rawContent
        self.source = source
    }
}

// MARK: - SKILL.md Parser
public struct SkillParser {
    
    public struct ParsedSkill {
        public let name: String
        public let description: String
        public let instructions: String
    }
    
    public enum ParseError: Error {
        case noFrontmatter
        case invalidYAML(String)
        case missingRequiredField(String)
    }
    
    public static func parse(_ content: String) throws -> ParsedSkill {
        // Split frontmatter from content
        let pattern = #"^---\s*\n([\s\S]*?)\n---\s*\n([\s\S]*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let frontmatterRange = Range(match.range(at: 1), in: content),
              let instructionsRange = Range(match.range(at: 2), in: content) else {
            throw ParseError.noFrontmatter
        }
        
        let frontmatterString = String(content[frontmatterRange])
        let instructions = String(content[instructionsRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Parse YAML frontmatter
        guard let yaml = try? Yams.load(yaml: frontmatterString) as? [String: Any] else {
            throw ParseError.invalidYAML("Could not parse YAML frontmatter")
        }
        
        guard let name = yaml["name"] as? String else {
            throw ParseError.missingRequiredField("name")
        }
        
        guard let description = yaml["description"] as? String else {
            throw ParseError.missingRequiredField("description")
        }
        
        return ParsedSkill(name: name, description: description, instructions: instructions)
    }
    
    public init() {}
}
```

**Validation Criteria:**
- [ ] Run `swift build --target ILSShared`
- [ ] Build succeeds with zero errors
- [ ] Evidence: Terminal output

**Evidence Required:**

```
EVIDENCE_1.3:
- Type: Terminal Output
- Command: `swift build --target ILSShared`
- Expected: "Build complete!"
- Actual: [PASTE OUTPUT]
- Status: PASS/FAIL
```

**BLOCKING:** Cannot proceed to 1.4 until PASS

---

### Task 1.4: Create Plugin.swift

**Sub-Agent Assignment:** MAIN AGENT

**File:** `Sources/ILSShared/Models/Plugin.swift`

```swift
import Foundation

public struct Plugin: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String?
    public var marketplace: String
    public var isInstalled: Bool
    public var isEnabled: Bool
    public var version: String?
    public var stars: Int?
    public var source: PluginSource
    
    public enum PluginSource: Codable, Sendable {
        case official
        case community(repository: String)
    }
    
    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        marketplace: String,
        isInstalled: Bool = false,
        isEnabled: Bool = false,
        version: String? = nil,
        stars: Int? = nil,
        source: PluginSource = .official
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.marketplace = marketplace
        self.isInstalled = isInstalled
        self.isEnabled = isEnabled
        self.version = version
        self.stars = stars
        self.source = source
    }
}

// MARK: - Plugin Manifest (plugin.json)
public struct PluginManifest: Codable, Sendable {
    public var name: String
    public var version: String?
    public var description: String?
    public var author: String?
    
    public init(name: String, version: String? = nil, description: String? = nil, author: String? = nil) {
        self.name = name
        self.version = version
        self.description = description
        self.author = author
    }
}

// MARK: - Marketplace Configuration
public struct Marketplace: Codable, Identifiable, Sendable {
    public var id: String { name }
    public var name: String
    public var owner: MarketplaceOwner?
    public var plugins: [MarketplacePlugin]
    public var source: String // GitHub repo
    
    public init(name: String, owner: MarketplaceOwner? = nil, plugins: [MarketplacePlugin] = [], source: String) {
        self.name = name
        self.owner = owner
        self.plugins = plugins
        self.source = source
    }
}

public struct MarketplaceOwner: Codable, Sendable {
    public var name: String
    public var url: String?
    
    public init(name: String, url: String? = nil) {
        self.name = name
        self.url = url
    }
}

public struct MarketplacePlugin: Codable, Identifiable, Sendable {
    public var id: String { name }
    public var name: String
    public var source: PluginSourceDefinition
    
    public init(name: String, source: PluginSourceDefinition) {
        self.name = name
        self.source = source
    }
}

public struct PluginSourceDefinition: Codable, Sendable {
    public var type: String // "local" or "github"
    public var path: String?
    public var repository: String?
    
    public init(type: String, path: String? = nil, repository: String? = nil) {
        self.type = type
        self.path = path
        self.repository = repository
    }
}
```

**Validation Criteria:**
- [ ] Run `swift build --target ILSShared`
- [ ] Build succeeds
- [ ] Evidence: Terminal output

**Evidence Required:**

```
EVIDENCE_1.4:
- Type: Terminal Output
- Command: `swift build --target ILSShared`
- Expected: "Build complete!"
- Actual: [PASTE OUTPUT]
- Status: PASS/FAIL
```

**BLOCKING:** Cannot proceed to 1.5 until PASS

---

### Task 1.5: Create ClaudeConfig.swift

**Sub-Agent Assignment:** MAIN AGENT

**File:** `Sources/ILSShared/Models/ClaudeConfig.swift`

```swift
import Foundation

public struct ClaudeConfig: Codable, Sendable {
    public var permissions: PermissionsConfig?
    public var env: [String: String]?
    public var model: String?
    public var hooks: HooksConfig?
    public var enabledPlugins: [String: Bool]?
    public var extraKnownMarketplaces: [String: MarketplaceConfig]?
    
    public init(
        permissions: PermissionsConfig? = nil,
        env: [String: String]? = nil,
        model: String? = nil,
        hooks: HooksConfig? = nil,
        enabledPlugins: [String: Bool]? = nil,
        extraKnownMarketplaces: [String: MarketplaceConfig]? = nil
    ) {
        self.permissions = permissions
        self.env = env
        self.model = model
        self.hooks = hooks
        self.enabledPlugins = enabledPlugins
        self.extraKnownMarketplaces = extraKnownMarketplaces
    }
}

public struct PermissionsConfig: Codable, Sendable {
    public var allow: [String]?
    public var deny: [String]?
    
    public init(allow: [String]? = nil, deny: [String]? = nil) {
        self.allow = allow
        self.deny = deny
    }
}

public struct HooksConfig: Codable, Sendable {
    public var preToolUse: [HookCommand]?
    public var postToolUse: [HookCommand]?
    
    public init(preToolUse: [HookCommand]? = nil, postToolUse: [HookCommand]? = nil) {
        self.preToolUse = preToolUse
        self.postToolUse = postToolUse
    }
}

public struct HookCommand: Codable, Sendable {
    public var matcher: String?
    public var command: String
    
    public init(matcher: String? = nil, command: String) {
        self.matcher = matcher
        self.command = command
    }
}

public struct MarketplaceConfig: Codable, Sendable {
    public var source: String
    public var repo: String
    
    public init(source: String, repo: String) {
        self.source = source
        self.repo = repo
    }
}

// MARK: - Config Scope Paths
public struct ClaudeConfigPaths {
    public static let userSettings = "~/.claude/settings.json"
    public static let projectSettings = ".claude/settings.json"
    public static let localSettings = ".claude/settings.local.json"
    public static let userMCP = "~/.claude.json"
    public static let projectMCP = ".mcp.json"
    public static let skillsDirectory = "~/.claude/skills"
    
    #if os(macOS)
    public static let managedSettings = "/Library/Application Support/ClaudeCode/managed-settings.json"
    public static let managedMCP = "/Library/Application Support/ClaudeCode/managed-mcp.json"
    #endif
    
    private init() {}
}
```

**Validation Criteria:**
- [ ] Run `swift build --target ILSShared`
- [ ] Build succeeds
- [ ] Evidence: Terminal output

**Evidence Required:**

```
EVIDENCE_1.5:
- Type: Terminal Output
- Command: `swift build --target ILSShared`
- Expected: "Build complete!"
- Actual: [PASTE OUTPUT]
- Status: PASS/FAIL
```

**BLOCKING:** Cannot proceed to 1.6 until PASS

---

### Task 1.6: Create DTOs - APIResponse.swift

**Sub-Agent Assignment:** MAIN AGENT

**File:** `Sources/ILSShared/DTOs/APIResponse.swift`

```swift
import Foundation

public struct APIResponse<T: Codable & Sendable>: Codable, Sendable {
    public let success: Bool
    public let data: T?
    public let error: APIError?
    public let timestamp: Date
    
    public init(success: Bool, data: T? = nil, error: APIError? = nil) {
        self.success = success
        self.data = data
        self.error = error
        self.timestamp = Date()
    }
    
    public static func success(_ data: T) -> APIResponse<T> {
        APIResponse(success: true, data: data)
    }
    
    public static func failure(_ error: APIError) -> APIResponse<T> {
        APIResponse(success: false, error: error)
    }
}

public struct APIError: Codable, Sendable, Error {
    public let code: String
    public let message: String
    public let details: String?
    
    public init(code: String, message: String, details: String? = nil) {
        self.code = code
        self.message = message
        self.details = details
    }
    
    public static let unauthorized = APIError(code: "UNAUTHORIZED", message: "Authentication required")
    public static let notFound = APIError(code: "NOT_FOUND", message: "Resource not found")
    public static let invalidRequest = APIError(code: "INVALID_REQUEST", message: "Invalid request parameters")
    public static let serverError = APIError(code: "SERVER_ERROR", message: "Internal server error")
}

// MARK: - List Response
public struct ListResponse<T: Codable & Sendable>: Codable, Sendable {
    public let items: [T]
    public let total: Int
    public let page: Int?
    public let pageSize: Int?
    
    public init(items: [T], total: Int? = nil, page: Int? = nil, pageSize: Int? = nil) {
        self.items = items
        self.total = total ?? items.count
        self.page = page
        self.pageSize = pageSize
    }
}

// MARK: - Dashboard Stats
public struct DashboardStats: Codable, Sendable {
    public let skills: ResourceStats
    public let mcpServers: ResourceStats
    public let plugins: ResourceStats
    
    public init(skills: ResourceStats, mcpServers: ResourceStats, plugins: ResourceStats) {
        self.skills = skills
        self.mcpServers = mcpServers
        self.plugins = plugins
    }
}

public struct ResourceStats: Codable, Sendable {
    public let total: Int
    public let active: Int
    
    public init(total: Int, active: Int) {
        self.total = total
        self.active = active
    }
}

// MARK: - Connection Response
public struct ConnectionResponse: Codable, Sendable {
    public let sessionId: String
    public let serverInfo: ServerInfo
    
    public init(sessionId: String, serverInfo: ServerInfo) {
        self.sessionId = sessionId
        self.serverInfo = serverInfo
    }
}

public struct ServerInfo: Codable, Sendable {
    public let claudeInstalled: Bool
    public let claudeVersion: String?
    public let configPaths: ConfigPathsInfo
    
    public init(claudeInstalled: Bool, claudeVersion: String? = nil, configPaths: ConfigPathsInfo) {
        self.claudeInstalled = claudeInstalled
        self.claudeVersion = claudeVersion
        self.configPaths = configPaths
    }
}

public struct ConfigPathsInfo: Codable, Sendable {
    public let userSettings: String
    public let userMCP: String
    public let skillsDirectory: String
    
    public init(userSettings: String, userMCP: String, skillsDirectory: String) {
        self.userSettings = userSettings
        self.userMCP = userMCP
        self.skillsDirectory = skillsDirectory
    }
}
```

**Validation Criteria:**
- [ ] Run `swift build --target ILSShared`
- [ ] Build succeeds
- [ ] Evidence: Terminal output

**Evidence Required:**

```
EVIDENCE_1.6:
- Type: Terminal Output
- Command: `swift build --target ILSShared`
- Expected: "Build complete!"
- Actual: [PASTE OUTPUT]
- Status: PASS/FAIL
```

**BLOCKING:** Cannot proceed to 1.7 until PASS

---

### Task 1.7: Create SearchResult.swift

**Sub-Agent Assignment:** MAIN AGENT

**File:** `Sources/ILSShared/DTOs/SearchResult.swift`

```swift
import Foundation

public struct GitHubSearchResult: Codable, Sendable {
    public let repository: String
    public let name: String
    public let description: String?
    public let stars: Int
    public let lastUpdated: Date
    public let htmlUrl: String
    public let skillPath: String?
    
    public init(
        repository: String,
        name: String,
        description: String? = nil,
        stars: Int,
        lastUpdated: Date,
        htmlUrl: String,
        skillPath: String? = nil
    ) {
        self.repository = repository
        self.name = name
        self.description = description
        self.stars = stars
        self.lastUpdated = lastUpdated
        self.htmlUrl = htmlUrl
        self.skillPath = skillPath
    }
}

// MARK: - GitHub API Response Models
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
        case name
        case path
        case htmlUrl = "html_url"
        case repository
    }
}

public struct GitHubRepository: Codable, Sendable {
    public let id: Int
    public let name: String
    public let fullName: String
    public let description: String?
    public let htmlUrl: String
    public let stargazersCount: Int
    public let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case fullName = "full_name"
        case description
        case htmlUrl = "html_url"
        case stargazersCount = "stargazers_count"
        case updatedAt = "updated_at"
    }
}

// MARK: - Install Request
public struct SkillInstallRequest: Codable, Sendable {
    public let repository: String
    public let skillPath: String?
    
    public init(repository: String, skillPath: String? = nil) {
        self.repository = repository
        self.skillPath = skillPath
    }
}

public struct PluginInstallRequest: Codable, Sendable {
    public let pluginName: String
    public let marketplace: String
    public let scope: MCPServer.ConfigScope
    
    public init(pluginName: String, marketplace: String, scope: MCPServer.ConfigScope = .user) {
        self.pluginName = pluginName
        self.marketplace = marketplace
        self.scope = scope
    }
}

public struct MCPServerCreateRequest: Codable, Sendable {
    public let name: String
    public let command: String
    public let args: [String]?
    public let env: [String: String]?
    public let scope: MCPServer.ConfigScope
    
    public init(name: String, command: String, args: [String]? = nil, env: [String: String]? = nil, scope: MCPServer.ConfigScope = .user) {
        self.name = name
        self.command = command
        self.args = args
        self.env = env
        self.scope = scope
    }
}
```

**Validation Criteria:**
- [ ] Run `swift build --target ILSShared`
- [ ] Build succeeds
- [ ] Evidence: Terminal output

**Evidence Required:**

```
EVIDENCE_1.7:
- Type: Terminal Output
- Command: `swift build --target ILSShared`
- Expected: "Build complete!"
- Actual: [PASTE OUTPUT]
- Status: PASS/FAIL
```

---

### GATE CHECK 1: Shared Models Complete

**Validation:**
- [ ] Run `swift build --target ILSShared` from project root
- [ ] Zero errors, zero warnings
- [ ] All 7 model files exist and compile

**Evidence Required:**

```
GATE_CHECK_1:
- Command: `swift build --target ILSShared 2>&1`
- Expected: "Build complete!" with no errors
- Actual: [PASTE FULL OUTPUT]
- File Count Verification: `ls -la Sources/ILSShared/**/*.swift | wc -l` = 7
- Status: PASS/FAIL
```

**BLOCKING:** PHASE 2 CANNOT START until Gate Check 1 = PASS

&lt;/phase_1&gt;

---

## PHASE 2A: Vapor Backend (SUB-AGENT ALPHA)

&lt;phase_2a&gt;

### Sub-Agent Prompt: ALPHA

```
<sub_agent_alpha>
You are SUB-AGENT ALPHA responsible for building the Vapor backend.

CRITICAL CONSTRAINTS:
- You may ONLY work on files in Sources/ILSBackend/
- You MUST import and use models from ILSShared - NO duplicating models
- Every file you create MUST compile before you proceed
- You validate via cURL - backend must respond correctly
- Do NOT proceed if compilation fails
- Report evidence for EVERY task

Your tasks are SEQUENTIAL - complete each fully before starting next.
</sub_agent_alpha>
```

---

### Task 2A.1: Create Backend Entry Point

**Sub-Agent Assignment:** ALPHA

**File:** `Sources/ILSBackend/App/entrypoint.swift`

```swift
import Vapor
import Logging

@main
struct Entrypoint {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        
        let app = try await Application.make(env)
        
        do {
            try await configure(app)
            try await app.execute()
        } catch {
            app.logger.report(error: error)
            try? await app.asyncShutdown()
            throw error
        }
    }
}
```

**File:** `Sources/ILSBackend/App/configure.swift`

```swift
import Vapor
import Fluent
import FluentSQLiteDriver
import ILSShared

func configure(_ app: Application) async throws {
    // CORS for iOS app
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .DELETE, .OPTIONS],
        allowedHeaders: [.accept, .authorization, .contentType, .origin]
    )
    app.middleware.use(CORSMiddleware(configuration: corsConfiguration))
    
    // Database
    app.databases.use(.sqlite(.memory), as: .sqlite)
    
    // Routes
    try routes(app)
    
    app.logger.info("ILS Backend configured successfully")
}
```

**File:** `Sources/ILSBackend/App/routes.swift`

```swift
import Vapor
import ILSShared

func routes(_ app: Application) throws {
    // Health check
    app.get("health") { req -> String in
        return "OK"
    }
    
    // API v1 group
    let api = app.grouped("api", "v1")
    
    // Register controllers
    try api.register(collection: StatsController())
    try api.register(collection: SkillsController())
    try api.register(collection: MCPController())
    try api.register(collection: PluginsController())
    try api.register(collection: ConfigController())
}
```

**Validation Criteria:**
- [ ] Run `swift build --target ILSBackend`
- [ ] Build will fail (controllers not yet created) - EXPECTED
- [ ] Verify entrypoint.swift and configure.swift syntax is correct

**Evidence Required:**

```
EVIDENCE_2A.1:
- Type: Terminal Output
- Command: `swift build --target ILSBackend 2>&1 | head -20`
- Expected: Compilation starts, fails on missing controllers (expected)
- Actual: [PASTE OUTPUT]
- Status: PASS (if fails only on missing controllers)
```

---

### Task 2A.2: Create StatsController

**Sub-Agent Assignment:** ALPHA

**File:** `Sources/ILSBackend/Controllers/StatsController.swift`

```swift
import Vapor
import ILSShared

struct StatsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let stats = routes.grouped("stats")
        stats.get(use: getDashboardStats)
    }
    
    @Sendable
    func getDashboardStats(req: Request) async throws -> APIResponse<DashboardStats> {
        // TODO: Replace with real data from SSH connection
        let stats = DashboardStats(
            skills: ResourceStats(total: 12, active: 10),
            mcpServers: ResourceStats(total: 8, healthy: 6),
            plugins: ResourceStats(total: 3, active: 3)
        )
        return .success(stats)
    }
}

// Extension to fix ResourceStats naming
extension ResourceStats {
    init(total: Int, healthy: Int) {
        self.init(total: total, active: healthy)
    }
}
```

**Validation Criteria:**
- [ ] File created at correct path
- [ ] Syntax valid (will verify in later build)

---

### Task 2A.3: Create SkillsController

**Sub-Agent Assignment:** ALPHA

**File:** `Sources/ILSBackend/Controllers/SkillsController.swift`

```swift
import Vapor
import ILSShared

struct SkillsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let skills = routes.grouped("skills")
        skills.get(use: listSkills)
        skills.get("search", use: searchSkills)
        skills.get(":id", use: getSkill)
        skills.post("install", use: installSkill)
        skills.delete(":id", use: deleteSkill)
    }
    
    @Sendable
    func listSkills(req: Request) async throws -> APIResponse<ListResponse<Skill>> {
        // Mock data - will be replaced with SSH file reading
        let skills = [
            Skill(
                name: "code-review",
                description: "Automated PR code review",
                version: "1.2.0",
                isActive: true,
                path: "~/.claude/skills/code-review",
                rawContent: "---\nname: code-review\ndescription: Automated PR code review\n---\n# Instructions\nReview code carefully."
            ),
            Skill(
                name: "test-generator",
                description: "Generate unit tests automatically",
                version: "2.0.1",
                isActive: true,
                path: "~/.claude/skills/test-generator",
                rawContent: "---\nname: test-generator\ndescription: Generate unit tests automatically\n---\n# Instructions\nGenerate comprehensive tests."
            )
        ]
        return .success(ListResponse(items: skills))
    }
    
    @Sendable
    func searchSkills(req: Request) async throws -> APIResponse<ListResponse<GitHubSearchResult>> {
        let query = req.query[String.self, at: "q"] ?? ""
        
        // TODO: Implement real GitHub search
        let results = [
            GitHubSearchResult(
                repository: "anthropics/claude-skills",
                name: "refactor-pro",
                description: "Advanced code refactoring skill",
                stars: 234,
                lastUpdated: Date(),
                htmlUrl: "https://github.com/anthropics/claude-skills"
            )
        ]
        return .success(ListResponse(items: results))
    }
    
    @Sendable
    func getSkill(req: Request) async throws -> APIResponse<Skill> {
        guard let idString = req.parameters.get("id"),
              let id = UUID(uuidString: idString) else {
            throw Abort(.badRequest, reason: "Invalid skill ID")
        }
        
        // Mock - will be replaced
        let skill = Skill(
            id: id,
            name: "code-review",
            description: "Automated PR code review",
            version: "1.2.0",
            isActive: true,
            path: "~/.claude/skills/code-review",
            rawContent: "---\nname: code-review\ndescription: Automated PR code review\n---\n# Instructions"
        )
        return .success(skill)
    }
    
    @Sendable
    func installSkill(req: Request) async throws -> APIResponse<Skill> {
        let installRequest = try req.content.decode(SkillInstallRequest.self)
        
        // TODO: Clone from GitHub, parse SKILL.md, install
        let skill = Skill(
            name: "installed-skill",
            description: "Newly installed skill",
            isActive: true,
            path: "~/.claude/skills/installed-skill",
            rawContent: "",
            source: .github(repository: installRequest.repository, stars: 0)
        )
        return .success(skill)
    }
    
    @Sendable
    func deleteSkill(req: Request) async throws -> APIResponse<Bool> {
        guard let _ = req.parameters.get("id") else {
            throw Abort(.badRequest, reason: "Invalid skill ID")
        }
        
        // TODO: Delete skill directory
        return .success(true)
    }
}
```

---

### Task 2A.4: Create MCPController

**Sub-Agent Assignment:** ALPHA

**File:** `Sources/ILSBackend/Controllers/MCPController.swift`

```swift
import Vapor
import ILSShared

struct MCPController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let mcp = routes.grouped("mcp")
        mcp.get(use: listMCPServers)
        mcp.post(use: createMCPServer)
        mcp.put(":name", use: updateMCPServer)
        mcp.delete(":name", use: deleteMCPServer)
    }
    
    @Sendable
    func listMCPServers(req: Request) async throws -> APIResponse<ListResponse<MCPServer>> {
        let scopeParam = req.query[String.self, at: "scope"]
        let scope = scopeParam.flatMap { MCPServer.ConfigScope(rawValue: $0) }
        
        // Mock data
        var servers = [
            MCPServer(
                name: "github",
                command: "npx",
                args: ["-y", "@mcp/server-github"],
                env: ["GITHUB_TOKEN": "***"],
                scope: .user,
                status: .healthy
            ),
            MCPServer(
                name: "filesystem",
                command: "npx",
                args: ["-y", "@mcp/server-filesystem", "--root", "~/projects"],
                env: [:],
                scope: .user,
                status: .healthy
            ),
            MCPServer(
                name: "postgres",
                command: "npx",
                args: ["-y", "@mcp/server-postgres"],
                env: ["DATABASE_URL": "postgres://..."],
                scope: .project,
                status: .error
            )
        ]
        
        if let scope = scope {
            servers = servers.filter { $0.scope == scope }
        }
        
        return .success(ListResponse(items: servers))
    }
    
    @Sendable
    func createMCPServer(req: Request) async throws -> APIResponse<MCPServer> {
        let createRequest = try req.content.decode(MCPServerCreateRequest.self)
        
        let server = MCPServer(
            name: createRequest.name,
            command: createRequest.command,
            args: createRequest.args ?? [],
            env: createRequest.env ?? [:],
            scope: createRequest.scope,
            status: .unknown
        )
        
        // TODO: Write to appropriate config file via SSH
        return .success(server)
    }
    
    @Sendable
    func updateMCPServer(req: Request) async throws -> APIResponse<MCPServer> {
        guard let name = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Server name required")
        }
        
        let updateRequest = try req.content.decode(MCPServerCreateRequest.self)
        
        let server = MCPServer(
            name: name,
            command: updateRequest.command,
            args: updateRequest.args ?? [],
            env: updateRequest.env ?? [:],
            scope: updateRequest.scope,
            status: .unknown
        )
        
        return .success(server)
    }
    
    @Sendable
    func deleteMCPServer(req: Request) async throws -> APIResponse<Bool> {
        guard let _ = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Server name required")
        }
        
        // TODO: Remove from config file via SSH
        return .success(true)
    }
}
```

---

### Task 2A.5: Create PluginsController

**Sub-Agent Assignment:** ALPHA

**File:** `Sources/ILSBackend/Controllers/PluginsController.swift`

```swift
import Vapor
import ILSShared

struct PluginsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let plugins = routes.grouped("plugins")
        plugins.get(use: listPlugins)
        plugins.get("marketplace", use: getMarketplaces)
        plugins.get("search", use: searchPlugins)
        plugins.post("install", use: installPlugin)
        
        let marketplaces = routes.grouped("marketplaces")
        marketplaces.post(use: addMarketplace)
    }
    
    @Sendable
    func listPlugins(req: Request) async throws -> APIResponse<ListResponse<Plugin>> {
        let plugins = [
            Plugin(
                name: "github",
                description: "GitHub integration plugin",
                marketplace: "claude-plugins-official",
                isInstalled: true,
                isEnabled: true,
                version: "1.0.0",
                stars: 2100,
                source: .official
            ),
            Plugin(
                name: "linear",
                description: "Linear project management integration",
                marketplace: "claude-plugins-official",
                isInstalled: false,
                isEnabled: false,
                version: "1.0.0",
                stars: 856,
                source: .official
            )
        ]
        return .success(ListResponse(items: plugins))
    }
    
    @Sendable
    func getMarketplaces(req: Request) async throws -> APIResponse<ListResponse<Marketplace>> {
        let marketplaces = [
            Marketplace(
                name: "claude-plugins-official",
                owner: MarketplaceOwner(name: "Anthropic", url: "https://anthropic.com"),
                plugins: [],
                source: "anthropics/claude-code"
            )
        ]
        return .success(ListResponse(items: marketplaces))
    }
    
    @Sendable
    func searchPlugins(req: Request) async throws -> APIResponse<ListResponse<Plugin>> {
        let query = req.query[String.self, at: "q"] ?? ""
        
        // TODO: Search across marketplaces
        let plugins: [Plugin] = []
        return .success(ListResponse(items: plugins))
    }
    
    @Sendable
    func installPlugin(req: Request) async throws -> APIResponse<Plugin> {
        let installRequest = try req.content.decode(PluginInstallRequest.self)
        
        let plugin = Plugin(
            name: installRequest.pluginName,
            marketplace: installRequest.marketplace,
            isInstalled: true,
            isEnabled: true,
            source: .official
        )
        
        // TODO: Run plugin install command via SSH
        return .success(plugin)
    }
    
    @Sendable
    func addMarketplace(req: Request) async throws -> APIResponse<Marketplace> {
        struct AddMarketplaceRequest: Content {
            let source: String
            let repo: String
        }
        
        let addRequest = try req.content.decode(AddMarketplaceRequest.self)
        
        let marketplace = Marketplace(
            name: addRequest.repo.replacingOccurrences(of: "/", with: "-"),
            plugins: [],
            source: addRequest.repo
        )
        
        return .success(marketplace)
    }
}
```

---

### Task 2A.6: Create ConfigController

**Sub-Agent Assignment:** ALPHA

**File:** `Sources/ILSBackend/Controllers/ConfigController.swift`

```swift
import Vapor
import ILSShared

struct ConfigController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let config = routes.grouped("config")
        config.get(use: getConfig)
        config.put(use: updateConfig)
        config.post("validate", use: validateConfig)
    }
    
    @Sendable
    func getConfig(req: Request) async throws -> ConfigResponse {
        let scopeParam = req.query[String.self, at: "scope"] ?? "user"
        let scope = MCPServer.ConfigScope(rawValue: scopeParam) ?? .user
        
        let path: String
        switch scope {
        case .user:
            path = ClaudeConfigPaths.userSettings
        case .project:
            path = ClaudeConfigPaths.projectSettings
        case .local:
            path = ClaudeConfigPaths.localSettings
        case .managed:
            #if os(macOS)
            path = ClaudeConfigPaths.managedSettings
            #else
            path = ClaudeConfigPaths.userSettings
            #endif
        }
        
        // Mock config - will be replaced with SSH file read
        let config = ClaudeConfig(
            permissions: PermissionsConfig(
                allow: ["Bash(npm run *)"],
                deny: ["Read(.env)"]
            ),
            model: "claude-sonnet-4-20250514"
        )
        
        return ConfigResponse(
            scope: scopeParam,
            path: path,
            content: config,
            isValid: true
        )
    }
    
    @Sendable
    func updateConfig(req: Request) async throws -> APIResponse<Bool> {
        struct UpdateRequest: Content {
            let scope: String
            let content: ClaudeConfig
        }
        
        let updateRequest = try req.content.decode(UpdateRequest.self)
        
        // TODO: Write config via SSH
        req.logger.info("Updating config for scope: \(updateRequest.scope)")
        
        return .success(true)
    }
    
    @Sendable
    func validateConfig(req: Request) async throws -> ValidationResponse {
        struct ValidateRequest: Content {
            let content: ClaudeConfig
        }
        
        do {
            let _ = try req.content.decode(ValidateRequest.self)
            return ValidationResponse(isValid: true, errors: [])
        } catch {
            return ValidationResponse(isValid: false, errors: [error.localizedDescription])
        }
    }
}

struct ConfigResponse: Content {
    let scope: String
    let path: String
    let content: ClaudeConfig
    let isValid: Bool
}

struct ValidationResponse: Content {
    let isValid: Bool
    let errors: [String]
}
```

---

### Task 2A.7: Build and Test Backend

**Sub-Agent Assignment:** ALPHA

**Actions:**

```bash
# Build backend
cd ILSApp
swift build --target ILSBackend

# If build succeeds, run the server
swift run ILSBackend &
SERVER_PID=$!
sleep 3

# Test health endpoint
curl -s http://localhost:8080/health

# Test stats endpoint
curl -s http://localhost:8080/api/v1/stats | jq

# Test skills list
curl -s http://localhost:8080/api/v1/skills | jq

# Test MCP list
curl -s http://localhost:8080/api/v1/mcp | jq

# Test plugins marketplace
curl -s http://localhost:8080/api/v1/plugins/marketplace | jq

# Test config
curl -s http://localhost:8080/api/v1/config | jq

# Cleanup
kill $SERVER_PID
```

**Validation Criteria:**
- [ ] `swift build --target ILSBackend` succeeds with zero errors
- [ ] Server starts and responds to health check
- [ ] ALL 5 API endpoints return valid JSON
- [ ] Evidence: Terminal output showing ALL cURL responses

**Evidence Required:**

```
EVIDENCE_2A.7:
- Type: Terminal Output (Multiple)

BUILD:
- Command: `swift build --target ILSBackend 2>&1`
- Expected: "Build complete!"
- Actual: [PASTE OUTPUT]

HEALTH CHECK:
- Command: `curl -s http://localhost:8080/health`
- Expected: "OK"
- Actual: [PASTE OUTPUT]

STATS ENDPOINT:
- Command: `curl -s http://localhost:8080/api/v1/stats`
- Expected: JSON with skills, mcpServers, plugins objects
- Actual: [PASTE FULL JSON]

SKILLS ENDPOINT:
- Command: `curl -s http://localhost:8080/api/v1/skills`
- Expected: JSON with items array containing skill objects
- Actual: [PASTE FULL JSON]

MCP ENDPOINT:
- Command: `curl -s http://localhost:8080/api/v1/mcp`
- Expected: JSON with items array containing MCP server objects
- Actual: [PASTE FULL JSON]

CONFIG ENDPOINT:
- Command: `curl -s http://localhost:8080/api/v1/config`
- Expected: JSON with scope, path, content, isValid fields
- Actual: [PASTE FULL JSON]

- Status: PASS/FAIL (ALL must succeed)
```

**BLOCKING:** Gate Check 2A cannot pass without ALL cURL tests succeeding

---

### GATE CHECK 2A: Backend Complete

```
GATE_CHECK_2A:
- Build Status: PASS/FAIL
- Health Endpoint: PASS/FAIL  
- Stats Endpoint: PASS/FAIL
- Skills Endpoint: PASS/FAIL
- MCP Endpoint: PASS/FAIL
- Plugins Endpoint: PASS/FAIL
- Config Endpoint: PASS/FAIL

OVERALL: PASS only if ALL = PASS
```

&lt;/phase_2a&gt;

---

## PHASE 2B: Design System (SUB-AGENT BETA)

&lt;phase_2b&gt;

### Sub-Agent Prompt: BETA

```
<sub_agent_beta>
You are SUB-AGENT BETA responsible for building the SwiftUI design system.

CRITICAL CONSTRAINTS:
- You work ONLY on Sources/ILSApp/Theme/ files
- Dark mode ONLY - no light mode support
- Hot Orange (#FF6B35) is the accent color
- Black (#000000) is the primary background
- Every file must compile in Xcode before proceeding
- You validate via Xcode Preview or Simulator screenshot

Your tasks are SEQUENTIAL.
</sub_agent_beta>
```

---

### Task 2B.1: Create Color Assets

**Sub-Agent Assignment:** BETA

**File:** `Sources/ILSApp/Resources/Assets.xcassets/Colors/AccentColor.colorset/Contents.json`

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.208",
          "green" : "0.420",
          "red" : "1.000"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

**Additional Color Sets to Create:**
- `BackgroundPrimary` - #000000
- `BackgroundSecondary` - #0D0D0D
- `BackgroundTertiary` - #1A1A1A
- `TextPrimary` - #FFFFFF
- `TextSecondary` - #A0A0A0
- `BorderDefault` - #2A2A2A
- `Success` - #4CAF50
- `Warning` - #FFA726
- `Error` - #EF5350

---

### Task 2B.2: Create ILSTheme.swift

**Sub-Agent Assignment:** BETA

**File:** `Sources/ILSApp/Theme/ILSTheme.swift`

```swift
import SwiftUI

enum ILSTheme {
    
    // MARK: - Colors
    enum Colors {
        static let backgroundPrimary = Color("BackgroundPrimary")
        static let backgroundSecondary = Color("BackgroundSecondary")
        static let backgroundTertiary = Color("BackgroundTertiary")
        
        static let accentPrimary = Color("AccentColor") // #FF6B35
        static let accentSecondary = Color(red: 1.0, green: 0.55, blue: 0.35) // #FF8C5A
        static let accentTertiary = Color(red: 1.0, green: 0.27, blue: 0.0) // #FF4500
        
        static let textPrimary = Color("TextPrimary")
        static let textSecondary = Color("TextSecondary")
        static let textTertiary = Color(white: 0.4)
        
        static let borderDefault = Color("BorderDefault")
        static let borderActive = Color("AccentColor")
        
        static let success = Color("Success")
        static let warning = Color("Warning")
        static let error = Color("Error")
        
        // Fallback colors for when assets aren't loaded
        static let fallbackBackground = Color.black
        static let fallbackAccent = Color(red: 1.0, green: 0.42, blue: 0.21)
    }
    
    // MARK: - Typography
    enum Typography {
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
        static let title1 = Font.system(size: 28, weight: .bold, design: .default)
        static let title2 = Font.system(size: 22, weight: .bold, design: .default)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .default)
        static let headline = Font.system(size: 17, weight: .semibold, design: .default)
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let callout = Font.system(size: 16, weight: .regular, design: .default)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
        static let footnote = Font.system(size: 13, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .regular, design: .default)
        static let code = Font.system(size: 14, weight: .regular, design: .monospaced)
    }
    
    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 24
    }
    
    // MARK: - Shadows (subtle for dark theme)
    enum Shadows {
        static let small = Shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        static let medium = Shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
        static let large = Shadow(color: .black.opacity(0.5), radius: 16, x: 0, y: 8)
    }
    
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

// MARK: - View Modifiers

struct ILSCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(ILSTheme.Colors.backgroundSecondary)
            .cornerRadius(ILSTheme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: ILSTheme.CornerRadius.medium)
                    .stroke(ILSTheme.Colors.borderDefault, lineWidth: 1)
            )
    }
}

struct ILSPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ILSTheme.Typography.headline)
            .foregroundColor(.white)
            .padding(.horizontal, ILSTheme.Spacing.lg)
            .padding(.vertical, ILSTheme.Spacing.md)
            .background(
                configuration.isPressed 
                    ? ILSTheme.Colors.accentTertiary 
                    : ILSTheme.Colors.accentPrimary
            )
            .cornerRadius(ILSTheme.CornerRadius.small)
    }
}

struct ILSSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ILSTheme.Typography.headline)
            .foregroundColor(ILSTheme.Colors.accentPrimary)
            .padding(.horizontal, ILSTheme.Spacing.lg)
            .padding(.vertical, ILSTheme.Spacing.md)
            .background(ILSTheme.Colors.backgroundTertiary)
            .cornerRadius(ILSTheme.CornerRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: ILSTheme.CornerRadius.small)
                    .stroke(ILSTheme.Colors.accentPrimary, lineWidth: 1)
            )
    }
}

struct ILSTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(ILSTheme.Spacing.md)
            .background(ILSTheme.Colors.backgroundTertiary)
            .cornerRadius(ILSTheme.CornerRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: ILSTheme.CornerRadius.small)
                    .stroke(ILSTheme.Colors.borderDefault, lineWidth: 1)
            )
    }
}

// MARK: - View Extensions

extension View {
    func ilsCard() -> some View {
        modifier(ILSCardStyle())
    }
}
```

**Validation Criteria:**
- [ ] Build succeeds in Xcode (⌘+B)
- [ ] No compilation errors
- [ ] Preview available (if preview code added)

**Evidence Required:**

```
EVIDENCE_2B.2:
- Type: Xcode Screenshot
- Shows: Build succeeded indicator + Theme file open
- Filename: evidence_2b2_theme_compiled.png
- Status: PASS/FAIL
```

---

### Task 2B.3: Create Theme Preview View

**Sub-Agent Assignment:** BETA

**File:** `Sources/ILSApp/Theme/ThemePreview.swift`

```swift
import SwiftUI

struct ThemePreviewView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ILSTheme.Spacing.lg) {
                // Colors Section
                Text("Colors")
                    .font(ILSTheme.Typography.title2)
                    .foregroundColor(ILSTheme.Colors.textPrimary)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: ILSTheme.Spacing.md) {
                    ColorSwatch(name: "Accent", color: ILSTheme.Colors.accentPrimary)
                    ColorSwatch(name: "BG Primary", color: ILSTheme.Colors.backgroundPrimary)
                    ColorSwatch(name: "BG Secondary", color: ILSTheme.Colors.backgroundSecondary)
                    ColorSwatch(name: "BG Tertiary", color: ILSTheme.Colors.backgroundTertiary)
                    ColorSwatch(name: "Text Primary", color: ILSTheme.Colors.textPrimary)
                    ColorSwatch(name: "Text Secondary", color: ILSTheme.Colors.textSecondary)
                    ColorSwatch(name: "Success", color: ILSTheme.Colors.success)
                    ColorSwatch(name: "Warning", color: ILSTheme.Colors.warning)
                    ColorSwatch(name: "Error", color: ILSTheme.Colors.error)
                }
                
                Divider()
                    .background(ILSTheme.Colors.borderDefault)
                
                // Buttons Section
                Text("Buttons")
                    .font(ILSTheme.Typography.title2)
                    .foregroundColor(ILSTheme.Colors.textPrimary)
                
                HStack(spacing: ILSTheme.Spacing.md) {
                    Button("Primary") {}
                        .buttonStyle(ILSPrimaryButtonStyle())
                    
                    Button("Secondary") {}
                        .buttonStyle(ILSSecondaryButtonStyle())
                }
                
                Divider()
                    .background(ILSTheme.Colors.borderDefault)
                
                // Typography Section
                Text("Typography")
                    .font(ILSTheme.Typography.title2)
                    .foregroundColor(ILSTheme.Colors.textPrimary)
                
                VStack(alignment: .leading, spacing: ILSTheme.Spacing.sm) {
                    Text("Large Title").font(ILSTheme.Typography.largeTitle)
                    Text("Title 1").font(ILSTheme.Typography.title1)
                    Text("Title 2").font(ILSTheme.Typography.title2)
                    Text("Title 3").font(ILSTheme.Typography.title3)
                    Text("Headline").font(ILSTheme.Typography.headline)
                    Text("Body").font(ILSTheme.Typography.body)
                    Text("Callout").font(ILSTheme.Typography.callout)
                    Text("Footnote").font(ILSTheme.Typography.footnote)
                    Text("let code = true").font(ILSTheme.Typography.code)
                }
                .foregroundColor(ILSTheme.Colors.textPrimary)
                
                Divider()
                    .background(ILSTheme.Colors.borderDefault)
                
                // Card Section
                Text("Cards")
                    .font(ILSTheme.Typography.title2)
                    .foregroundColor(ILSTheme.Colors.textPrimary)
                
                VStack(alignment: .leading, spacing: ILSTheme.Spacing.sm) {
                    Text("Card Title")
                        .font(ILSTheme.Typography.headline)
                        .foregroundColor(ILSTheme.Colors.textPrimary)
                    Text("This is a card component with the ILS theme applied.")
                        .font(ILSTheme.Typography.body)
                        .foregroundColor(ILSTheme.Colors.textSecondary)
                }
                .padding(ILSTheme.Spacing.md)
                .ilsCard()
            }
            .padding(ILSTheme.Spacing.lg)
        }
        .background(ILSTheme.Colors.backgroundPrimary)
    }
}

struct ColorSwatch: View {
    let name: String
    let color: Color
    
    var body: some View {
        VStack(spacing: ILSTheme.Spacing.xs) {
            RoundedRectangle(cornerRadius: ILSTheme.CornerRadius.small)
                .fill(color)
                .frame(height: 50)
                .overlay(
                    RoundedRectangle(cornerRadius: ILSTheme.CornerRadius.small)
                        .stroke(ILSTheme.Colors.borderDefault, lineWidth: 1)
                )
            Text(name)
                .font(ILSTheme.Typography.caption)
                .foregroundColor(ILSTheme.Colors.textSecondary)
        }
    }
}

#Preview {
    ThemePreviewView()
        .preferredColorScheme(.dark)
}
```

**Validation Criteria:**
- [ ] Build succeeds in Xcode
- [ ] Preview renders showing:
- Hot orange accent color (#FF6B35)
- Pure black background (#000000)
- All color swatches visible
- Primary and Secondary buttons
- Typography scale
- Card component
- 
  - [ ] Evidence: Screenshot of Xcode Preview canvas

**Evidence Required:**

```
EVIDENCE_2B.3:
- Type: Xcode Preview Screenshot
- Shows: ThemePreviewView with all design tokens visible
- Must Show:
  - [ ] Hot orange accent color
  - [ ] Black background
  - [ ] Primary button (orange)
  - [ ] Secondary button (outlined)
  - [ ] Typography samples
  - [ ] Card with border
- Filename: evidence_2b3_theme_preview.png
- Status: PASS/FAIL
```

**BLOCKING:** Gate Check 2B cannot pass without this screenshot

---

### GATE CHECK 2B: Design System Complete

```
GATE_CHECK_2B:
- ILSTheme.swift compiles: PASS/FAIL
- ThemePreview.swift compiles: PASS/FAIL
- Preview Screenshot captured: PASS/FAIL
- Screenshot shows correct colors: PASS/FAIL

OVERALL: PASS only if ALL = PASS
```

&lt;/phase_2b&gt;

---

## GATE CHECK 2: Sync Point

&lt;gate_check_2&gt;

**BOTH Sub-Agents must complete before proceeding:**

```
GATE_CHECK_2_SYNC:
- Gate Check 2A (Backend): PASS/FAIL
- Gate Check 2B (Design System): PASS/FAIL

PROCEED TO PHASE 3: Only if BOTH = PASS
```

**If either fails:**
- Identify failing sub-agent
- Review evidence
- Fix issues
- Re-run validation
- DO NOT proceed until both pass

&lt;/gate_check_2&gt;

---

## PHASE 3: iOS App - View by View

&lt;phase_3&gt;

### CRITICAL: Sequential Execution Only

Each view MUST:
1. Be coded completely
2. Compile without errors
3. Render in Simulator
4. Screenshot captured as evidence
5. ONLY THEN proceed to next view

---

### Task 3.1: Create ServerConnectionView

**Sub-Agent Assignment:** MAIN AGENT

**File:** `Sources/ILSApp/Views/ServerConnection/ServerConnectionView.swift`

```swift
import SwiftUI

struct ServerConnectionView: View {
    @State private var host: String = ""
    @State private var port: String = "22"
    @State private var username: String = ""
    @State private var authMethod: AuthMethod = .sshKey
    @State private var password: String = ""
    @State private var keyPath: String = ""
    @State private var isConnecting: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    
    enum AuthMethod: String, CaseIterable {
        case password = "Password"
        case sshKey = "SSH Key"
    }
    
    // Mock recent connections
    let recentConnections = [
        ("home-server", "<your-local-ip>", true),
        ("dev-box", "10.0.0.5", false)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ILSTheme.Spacing.lg) {
                    // Header Icon
                    Image(systemName: "server.rack")
                        .font(.system(size: 64))
                        .foregroundColor(ILSTheme.Colors.accentPrimary)
                        .padding(.top, ILSTheme.Spacing.xl)
                    
                    Text("Connect to Server")
                        .font(ILSTheme.Typography.title1)
                        .foregroundColor(ILSTheme.Colors.textPrimary)
                    
                    // Connection Form
                    VStack(spacing: ILSTheme.Spacing.md) {
                        // Host
                        ILSTextField(
                            title: "Host",
                            placeholder: "<your-local-ip> or hostname",
                            text: $host
                        )
                        
                        // Port
                        ILSTextField(
                            title: "Port",
                            placeholder: "22",
                            text: $port
                        )
                        .keyboardType(.numberPad)
                        
                        // Username
                        ILSTextField(
                            title: "Username",
                            placeholder: "admin",
                            text: $username
                        )
                        
                        // Auth Method Picker
                        VStack(alignment: .leading, spacing: ILSTheme.Spacing.sm) {
                            Text("Authentication")
                                .font(ILSTheme.Typography.subheadline)
                                .foregroundColor(ILSTheme.Colors.textSecondary)
                            
                            Picker("Auth Method", selection: $authMethod) {
                                ForEach(AuthMethod.allCases, id: \.self) { method in
                                    Text(method.rawValue).tag(method)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        // Conditional Auth Fields
                        if authMethod == .password {
                            ILSSecureField(
                                title: "Password",
                                placeholder: "Enter password",
                                text: $password
                            )
                        } else {
                            ILSTextField(
                                title: "SSH Key Path",
                                placeholder: "~/.ssh/id_rsa",
                                text: $keyPath
                            )
                            
                            Button("Select Key File...") {
                                // TODO: File picker
                            }
                            .buttonStyle(ILSSecondaryButtonStyle())
                        }
                    }
                    .padding(ILSTheme.Spacing.md)
                    .ilsCard()
                    
                    // Connect Button
                    Button(action: connect) {
                        HStack {
                            if isConnecting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(isConnecting ? "Connecting..." : "Connect")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ILSPrimaryButtonStyle())
                    .disabled(isConnecting || host.isEmpty || username.isEmpty)
                    
                    // Recent Connections
                    if !recentConnections.isEmpty {
                        VStack(alignment: .leading, spacing: ILSTheme.Spacing.sm) {
                            Text("Recent Connections")
                                .font(ILSTheme.Typography.headline)
                                .foregroundColor(ILSTheme.Colors.textPrimary)
                            
                            ForEach(recentConnections, id: \.1) { connection in
                                RecentConnectionRow(
                                    label: connection.0,
                                    host: connection.1,
                                    isOnline: connection.2
                                )
                            }
                        }
                        .padding(ILSTheme.Spacing.md)
                        .ilsCard()
                    }
                    
                    Spacer(minLength: ILSTheme.Spacing.xl)
                }
                .padding(.horizontal, ILSTheme.Spacing.lg)
            }
            .background(ILSTheme.Colors.backgroundPrimary)
            .navigationBarTitleDisplayMode(.inline)
            .alert("Connection Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func connect() {
        isConnecting = true
        // TODO: Implement actual SSH connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isConnecting = false
        }
    }
}

// MARK: - Supporting Views

struct ILSTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: ILSTheme.Spacing.xs) {
            Text(title)
                .font(ILSTheme.Typography.subheadline)
                .foregroundColor(ILSTheme.Colors.textSecondary)
            
            TextField(placeholder, text: $text)
                .font(ILSTheme.Typography.body)
                .foregroundColor(ILSTheme.Colors.textPrimary)
                .padding(ILSTheme.Spacing.md)
                .background(ILSTheme.Colors.backgroundTertiary)
                .cornerRadius(ILSTheme.CornerRadius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: ILSTheme.CornerRadius.small)
                        .stroke(ILSTheme.Colors.borderDefault, lineWidth: 1)
                )
        }
    }
}

struct ILSSecureField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: ILSTheme.Spacing.xs) {
            Text(title)
                .font(ILSTheme.Typography.subheadline)
                .foregroundColor(ILSTheme.Colors.textSecondary)
            
            SecureField(placeholder, text: $text)
                .font(ILSTheme.Typography.body)
                .foregroundColor(ILSTheme.Colors.textPrimary)
                .padding(ILSTheme.Spacing.md)
                .background(ILSTheme.Colors.backgroundTertiary)
                .cornerRadius(ILSTheme.CornerRadius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: ILSTheme.CornerRadius.small)
                        .stroke(ILSTheme.Colors.borderDefault, lineWidth: 1)
                )
        }
    }
}

struct RecentConnectionRow: View {
    let label: String
    let host: String
    let isOnline: Bool
    
    var body: some View {
        HStack {
            Circle()
                .fill(isOnline ? ILSTheme.Colors.success : ILSTheme.Colors.textTertiary)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(ILSTheme.Typography.body)
                    .foregroundColor(ILSTheme.Colors.textPrimary)
                Text(host)
                    .font(ILSTheme.Typography.caption)
                    .foregroundColor(ILSTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(ILSTheme.Colors.textTertiary)
        }
        .padding(ILSTheme.Spacing.md)
        .background(ILSTheme.Colors.backgroundTertiary)
        .cornerRadius(ILSTheme.CornerRadius.small)
    }
}

#Preview {
    ServerConnectionView()
        .preferredColorScheme(.dark)
}
```

**Validation Criteria:**
- [ ] Build succeeds (⌘+B)
- [ ] Run in iOS Simulator (⌘+R)
- [ ] Screenshot showing:
- Server icon in hot orange
- "Connect to Server" title
- Host, Port, Username fields
- Auth method segmented control
- Orange "Connect" button
- Recent connections list
- Pure black background

**Evidence Required:**

```
EVIDENCE_3.1:
- Type: iOS Simulator Screenshot
- Device: iPhone 15 Pro (or similar)
- Shows: ServerConnectionView fully rendered
- Must Verify:
  - [ ] Black background (#000000)
  - [ ] Orange server icon
  - [ ] All form fields visible
  - [ ] Connect button is orange
  - [ ] Recent connections show green/gray dots
- Filename: evidence_3.1_server_connection.png
- Status: PASS/FAIL
```

**BLOCKING:** Cannot proceed to 3.2 until screenshot evidence shows PASS

---

### Task 3.2: Create DashboardView

**Sub-Agent Assignment:** MAIN AGENT

**File:** `Sources/ILSApp/Views/Dashboard/DashboardView.swift`

```swift
import SwiftUI

struct DashboardView: View {
    @State private var stats = DashboardStats(
        skills: ResourceStats(total: 12, active: 10),
        mcpServers: ResourceStats(total: 8, active: 6),
        plugins: ResourceStats(total: 3, active: 3)
    )
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ILSTheme.Spacing.lg) {
                    // Stats Cards
                    HStack(spacing: ILSTheme.Spacing.md) {
                        StatCard(
                            title: "Skills",
                            value: stats.skills.total,
                            active: stats.skills.active,
                            icon: "book.closed.fill"
                        )
                        StatCard(
                            title: "MCPs",
                            value: stats.mcpServers.total,
                            active: stats.mcpServers.active,
                            icon: "server.rack"
                        )
                        StatCard(
                            title: "Plugins",
                            value: stats.plugins.total,
                            active: stats.plugins.active,
                            icon: "puzzlepiece.fill"
                        )
                    }
                    
                    // Quick Actions
                    VStack(alignment: .leading, spacing: ILSTheme.Spacing.sm) {
                        Text("Quick Actions")
                            .font(ILSTheme.Typography.headline)
                            .foregroundColor(ILSTheme.Colors.textPrimary)
                        
                        QuickActionRow(
                            icon: "magnifyingglass",
                            title: "Discover New Skills",
                            destination: AnyView(Text("Skills Search"))
                        )
                        QuickActionRow(
                            icon: "shippingbox.fill",
                            title: "Browse Plugin Market",
                            destination: AnyView(Text("Plugin Market"))
                        )
                        QuickActionRow(
                            icon: "wrench.and.screwdriver.fill",
                            title: "Configure MCP Servers",
                            destination: AnyView(Text("MCP Config"))
                        )
                        QuickActionRow(
                            icon: "gearshape.fill",
                            title: "Edit Claude Settings",
                            destination: AnyView(Text("Settings"))
                        )
                    }
                    .padding(ILSTheme.Spacing.md)
                    .ilsCard()
                    
                    // Recent Activity
                    VStack(alignment: .leading, spacing: ILSTheme.Spacing.sm) {
                        Text("Recent Activity")
                            .font(ILSTheme.Typography.headline)
                            .foregroundColor(ILSTheme.Colors.textPrimary)
                        
                        ActivityRow(
                            icon: "checkmark.circle.fill",
                            iconColor: ILSTheme.Colors.success,
                            title: "Installed code-review",
                            subtitle: "2 hours ago"
                        )
                        ActivityRow(
                            icon: "arrow.triangle.2.circlepath",
                            iconColor: ILSTheme.Colors.accentPrimary,
                            title: "Updated github MCP",
                            subtitle: "Yesterday"
                        )
                    }
                    .padding(ILSTheme.Spacing.md)
                    .ilsCard()
                    
                    Spacer(minLength: ILSTheme.Spacing.xl)
                }
                .padding(.horizontal, ILSTheme.Spacing.lg)
                .padding(.top, ILSTheme.Spacing.md)
            }
            .background(ILSTheme.Colors.backgroundPrimary)
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: ILSTheme.Spacing.sm) {
                        Circle()
                            .fill(ILSTheme.Colors.success)
                            .frame(width: 8, height: 8)
                        Text("home-server")
                            .font(ILSTheme.Typography.caption)
                            .foregroundColor(ILSTheme.Colors.textSecondary)
                    }
                }
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: Int
    let active: Int
    let icon: String
    
    var body: some View {
        VStack(spacing: ILSTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(ILSTheme.Colors.accentPrimary)
            
            Text("\(value)")
                .font(ILSTheme.Typography.title1)
                .foregroundColor(ILSTheme.Colors.textPrimary)
            
            Text(title)
                .font(ILSTheme.Typography.caption)
                .foregroundColor(ILSTheme.Colors.textSecondary)
            
            Text("\(active) active")
                .font(ILSTheme.Typography.caption)
                .foregroundColor(ILSTheme.Colors.success)
        }
        .frame(maxWidth: .infinity)
        .padding(ILSTheme.Spacing.md)
        .ilsCard()
    }
}

struct QuickActionRow: View {
    let icon: String
    let title: String
    let destination: AnyView
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(ILSTheme.Colors.accentPrimary)
                    .frame(width: 32)
                
                Text(title)
                    .font(ILSTheme.Typography.body)
                    .foregroundColor(ILSTheme.Colors.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(ILSTheme.Colors.textTertiary)
            }
            .padding(ILSTheme.Spacing.md)
            .background(ILSTheme.Colors.backgroundTertiary)
            .cornerRadius(ILSTheme.CornerRadius.small)
        }
    }
}

struct ActivityRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ILSTheme.Typography.body)
                    .foregroundColor(ILSTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(ILSTheme.Typography.caption)
                    .foregroundColor(ILSTheme.Colors.textSecondary)
            }
            
            Spacer()
        }
        .padding(ILSTheme.Spacing.sm)
    }
}

#Preview {
    DashboardView()
        .preferredColorScheme(.dark)
}
```

**Validation Criteria:**
- [ ] Build succeeds
- [ ] Run in Simulator
- [ ] Screenshot showing:
- Navigation bar with "Dashboard" title
- Server status indicator (green dot + "home-server")
- Three stat cards (Skills: 12, MCPs: 8, Plugins: 3)
- Quick Actions section with 4 rows
- Recent Activity section with 2 entries
- Black background throughout

**Evidence Required:**

```
EVIDENCE_3.2:
- Type: iOS Simulator Screenshot
- Shows: DashboardView fully rendered
- Must Verify:
  - [ ] Stats cards show correct numbers (12, 8, 3)
  - [ ] Orange icons on stat cards
  - [ ] Quick actions with chevrons
  - [ ] Activity rows with colored icons
  - [ ] Green status dot in nav bar
- Filename: evidence_3.2_dashboard.png
- Status: PASS/FAIL
```

**BLOCKING:** Cannot proceed to 3.3 until screenshot evidence shows PASS

---

### Task 3.3: Create SkillsListView

**Sub-Agent Assignment:** MAIN AGENT

**File:** `Sources/ILSApp/Views/Skills/SkillsListView.swift`

```swift
import SwiftUI
import ILSShared

struct SkillsListView: View {
    @State private var searchText: String = ""
    @State private var skills: [Skill] = [
        Skill(
            name: "code-review",
            description: "Automated PR code review",
            version: "1.2.0",
            isActive: true,
            path: "~/.claude/skills/code-review",
            rawContent: ""
        ),
        Skill(
            name: "test-generator",
            description: "Generate unit tests automatically",
            version: "2.0.1",
            isActive: true,
            path: "~/.claude/skills/test-generator",
            rawContent: ""
        ),
        Skill(
            name: "analytics",
            description: "Code analytics & metrics",
            version: "1.0.0",
            isActive: false,
            path: "~/.claude/skills/analytics",
            rawContent: ""
        )
    ]
    
    @State private var discoveredSkills: [GitHubSearchResult] = [
        GitHubSearchResult(
            repository: "anthropics/claude-skills",
            name: "refactor-pro",
            description: "Advanced refactoring skill",
            stars: 234,
            lastUpdated: Date(),
            htmlUrl: "https://github.com/anthropics/claude-skills"
        )
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ILSTheme.Spacing.lg) {
                    // Installed Skills Section
                    VStack(alignment: .leading, spacing: ILSTheme.Spacing.sm) {
                        Text("Installed Skills")
                            .font(ILSTheme.Typography.headline)
                            .foregroundColor(ILSTheme.Colors.textPrimary)
                        
                        ForEach(skills) { skill in
                            NavigationLink(destination: SkillDetailView(skill: skill)) {
                                SkillRow(skill: skill)
                            }
                        }
                    }
                    .padding(ILSTheme.Spacing.md)
                    .ilsCard()
                    
                    // Search Field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(ILSTheme.Colors.textSecondary)
                        
                        TextField("Search Skill Repos...", text: $searchText)
                            .font(ILSTheme.Typography.body)
                            .foregroundColor(ILSTheme.Colors.textPrimary)
                    }
                    .padding(ILSTheme.Spacing.md)
                    .background(ILSTheme.Colors.backgroundTertiary)
                    .cornerRadius(ILSTheme.CornerRadius.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: ILSTheme.CornerRadius.small)
                            .stroke(ILSTheme.Colors.borderDefault, lineWidth: 1)
                    )
                    
                    // Discovered Skills Section
                    VStack(alignment: .leading, spacing: ILSTheme.Spacing.sm) {
                        Text("Discovered from GitHub")
                            .font(ILSTheme.Typography.headline)
                            .foregroundColor(ILSTheme.Colors.textPrimary)
                        
                        ForEach(discoveredSkills, id: \.repository) { result in
                            DiscoveredSkillRow(result: result) {
                                // Install action
                            }
                        }
                    }
                    .padding(ILSTheme.Spacing.md)
                    .ilsCard()
                    
                    Spacer(minLength: ILSTheme.Spacing.xl)
                }
                .padding(.horizontal, ILSTheme.Spacing.lg)
                .padding(.top, ILSTheme.Spacing.md)
            }
            .background(ILSTheme.Colors.backgroundPrimary)
            .navigationTitle("Skills")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "plus")
                            .foregroundColor(ILSTheme.Colors.accentPrimary)
                    }
                }
            }
        }
    }
}

struct SkillRow: View {
    let skill: Skill
    
    var body: some View {
        HStack {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 24))
                .foregroundColor(ILSTheme.Colors.accentPrimary)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(skill.name)
                    .font(ILSTheme.Typography.body)
                    .foregroundColor(ILSTheme.Colors.textPrimary)
                
                Text(skill.description)
                    .font(ILSTheme.Typography.caption)
                    .foregroundColor(ILSTheme.Colors.textSecondary)
                    .lineLimit(1)
                
                HStack(spacing: ILSTheme.Spacing.sm) {
                    if let version = skill.version {
                        Text("v\(version)")
                            .font(ILSTheme.Typography.caption)
                            .foregroundColor(ILSTheme.Colors.textTertiary)
                    }
                    
                    StatusBadge(isActive: skill.isActive)
                }
            }
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .foregroundColor(ILSTheme.Colors.textSecondary)
            }
        }
        .padding(ILSTheme.Spacing.md)
        .background(ILSTheme.Colors.backgroundTertiary)
        .cornerRadius(ILSTheme.CornerRadius.small)
    }
}

struct StatusBadge: View {
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isActive ? ILSTheme.Colors.success : ILSTheme.Colors.textTertiary)
                .frame(width: 6, height: 6)
            
            Text(isActive ? "Active" : "Disabled")
                .font(ILSTheme.Typography.caption)
                .foregroundColor(isActive ? ILSTheme.Colors.success : ILSTheme.Colors.textTertiary)
        }
    }
}

struct DiscoveredSkillRow: View {
    let result: GitHubSearchResult
    let onInstall: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(ILSTheme.Colors.warning)
                    Text("\(result.stars)")
                        .font(ILSTheme.Typography.caption)
                        .foregroundColor(ILSTheme.Colors.textSecondary)
                    
                    Text(result.name)
                        .font(ILSTheme.Typography.body)
                        .foregroundColor(ILSTheme.Colors.textPrimary)
                }
                
                if let description = result.description {
                    Text(description)
                        .font(ILSTheme.Typography.caption)
                        .foregroundColor(ILSTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Button("Install", action: onInstall)
                .font(ILSTheme.Typography.caption)
                .foregroundColor(.white)
                .padding(.horizontal, ILSTheme.Spacing.md)
                .padding(.vertical, ILSTheme.Spacing.sm)
                .background(ILSTheme.Colors.accentPrimary)
                .cornerRadius(ILSTheme.CornerRadius.small)
        }
        .padding(ILSTheme.Spacing.md)
        .background(ILSTheme.Colors.backgroundTertiary)
        .cornerRadius(ILSTheme.CornerRadius.small)
    }
}

#Preview {
    SkillsListView()
        .preferredColorScheme(.dark)
}
```

**File:** `Sources/ILSApp/Views/Skills/SkillDetailView.swift`

```swift
import SwiftUI
import ILSShared

struct SkillDetailView: View {
    let skill: Skill
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: ILSTheme.Spacing.lg) {
                // Header
                VStack(spacing: ILSTheme.Spacing.md) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 48))
                        .foregroundColor(ILSTheme.Colors.accentPrimary)
                    
                    Text(skill.name)
                        .font(ILSTheme.Typography.title1)
                        .foregroundColor(ILSTheme.Colors.textPrimary)
                    
                    if let version = skill.version {
                        Text("v\(version)")
                            .font(ILSTheme.Typography.subheadline)
                            .foregroundColor(ILSTheme.Colors.textSecondary)
                    }
                    
                    HStack(spacing: ILSTheme.Spacing.md) {
                        if case .github(let repo, let stars) = skill.source {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(ILSTheme.Colors.warning)
                                Text("\(stars)")
                            }
                            .font(ILSTheme.Typography.caption)
                            .foregroundColor(ILSTheme.Colors.textSecondary)
                            
                            Text(repo)
                                .font(ILSTheme.Typography.caption)
                                .foregroundColor(ILSTheme.Colors.textSecondary)
                        }
                        
                        StatusBadge(isActive: skill.isActive)
                    }
                }
                .padding(ILSTheme.Spacing.lg)
                .frame(maxWidth: .infinity)
                .ilsCard()
                
                // Description
                VStack(alignment: .leading, spacing: ILSTheme.Spacing.sm) {
                    Text("Description")
                        .font(ILSTheme.Typography.headline)
                        .foregroundColor(ILSTheme.Colors.textPrimary)
                    
                    Text(skill.description)
                        .font(ILSTheme.Typography.body)
                        .foregroundColor(ILSTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(ILSTheme.Spacing.md)
                .ilsCard()
                
                // SKILL.md Preview
                VStack(alignment: .leading, spacing: ILSTheme.Spacing.sm) {
                    Text("SKILL.md Preview")
                        .font(ILSTheme.Typography.headline)
                        .foregroundColor(ILSTheme.Colors.textPrimary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(skill.rawContent.isEmpty ? "No content available" : skill.rawContent)
                            .font(ILSTheme.Typography.code)
                            .foregroundColor(ILSTheme.Colors.textSecondary)
                    }
                    .padding(ILSTheme.Spacing.md)
                    .background(ILSTheme.Colors.backgroundPrimary)
                    .cornerRadius(ILSTheme.CornerRadius.small)
                }
                .padding(ILSTheme.Spacing.md)
                .ilsCard()
                
                // Actions
                VStack(spacing: ILSTheme.Spacing.md) {
                    Button(action: { showDeleteConfirmation = true }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Uninstall")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .foregroundColor(.white)
                    .padding(ILSTheme.Spacing.md)
                    .background(ILSTheme.Colors.error)
                    .cornerRadius(ILSTheme.CornerRadius.small)
                    
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Edit SKILL.md")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ILSSecondaryButtonStyle())
                }
                
                Spacer(minLength: ILSTheme.Spacing.xl)
            }
            .padding(.horizontal, ILSTheme.Spacing.lg)
            .padding(.top, ILSTheme.Spacing.md)
        }
        .background(ILSTheme.Colors.backgroundPrimary)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Uninstall Skill",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Uninstall", role: .destructive) {}
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to uninstall \(skill.name)?")
        }
    }
}

#Preview {
    NavigationStack {
        SkillDetailView(skill: Skill(
            name: "code-review",
            description: "Automated PR code review that analyzes code for issues, security vulnerabilities, and suggests improvements.",
            version: "1.2.0",
            isActive: true,
            path: "~/.claude/skills/code-review",
            rawContent: "---\nname: code-review\ndescription: Reviews code\n---\n## Instructions\nWhen reviewing code...",
            source: .github(repository: "anthropics/claude-skills", stars: 1234)
        ))
    }
    .preferredColorScheme(.dark)
}
```

**Validation Criteria:**
- [ ] Both files compile
- [ ] SkillsListView renders in Simulator showing:
- "Skills" navigation title
- Plus button in toolbar
- Installed Skills section with 3 skills
- Search field
- Discovered from GitHub section
- Orange Install button
- 
  - [ ] SkillDetailView accessible via navigation

**Evidence Required:**

```
EVIDENCE_3.3:
- Type: iOS Simulator Screenshot (2 screenshots)

Screenshot 1 - Skills List:
- Shows: SkillsListView
- Must Verify:
  - [ ] 3 installed skills visible
  - [ ] Status badges (Active/Disabled)
  - [ ] Search field present
  - [ ] Discovered skill with Install button
- Filename: evidence_3.3a_skills_list.png

Screenshot 2 - Skill Detail:
- Shows: SkillDetailView (tap into a skill)
- Must Verify:
  - [ ] Skill icon and name
  - [ ] Description section
  - [ ] SKILL.md preview section
  - [ ] Red Uninstall button
  - [ ] Edit SKILL.md button
- Filename: evidence_3.3b_skill_detail.png

- Status: PASS/FAIL (both screenshots required)
```

**BLOCKING:** Cannot proceed to 3.4 until BOTH screenshots show PASS

---

### Task 3.4: Create MCPServerListView

**Sub-Agent Assignment:** MAIN AGENT

**File:** `Sources/ILSApp/Views/MCP/MCPServerListView.swift`

```swift
import SwiftUI
import ILSShared

struct MCPServerListView: View {
    @State private var selectedScope: MCPServer.ConfigScope = .user
    @State private var servers: [MCPServer] = [
        MCPServer(
            name: "github",
            command: "npx",
            args: ["-y", "@mcp/server-github"],
            env: ["GITHUB_TOKEN": "***"],
            scope: .user,
            status: .healthy
        ),
        MCPServer(
            name: "filesystem",
            command: "npx",
            args: ["-y", "@mcp/server-filesystem", "--root", "~/projects"],
            env: [:],
            scope: .user,
            status: .healthy
        ),
        MCPServer(
            name: "postgres",
            command: "npx",
            args: ["-y", "@mcp/server-postgres"],
            env: ["DATABASE_URL": "postgres://localhost/db"],
            scope: .project,
            status: .error
        )
    ]
    
    @State private var showAddSheet = false
    
    var filteredServers: [MCPServer] {
        servers.filter { $0.scope == selectedScope }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ILSTheme.Spacing.lg) {
                    // Scope Picker
                    Picker("Scope", selection: $selectedScope) {
                        Text("User").tag(MCPServer.ConfigScope.user)
                        Text("Project").tag(MCPServer.ConfigScope.project)
                        Text("Local").tag(MCPServer.ConfigScope.local)
                    }
                    .pickerStyle(.segmented)
                    
                    // Active Servers Section
                    VStack(alignment: .leading, spacing: ILSTheme.Spacing.sm) {
                        Text("Active Servers")
                            .font(ILSTheme.Typography.headline)
                            .foregroundColor(ILSTheme.Colors.textPrimary)
                        
                        if filteredServers.isEmpty {
                            Text("No servers configured for this scope")
                                .font(ILSTheme.Typography.body)
                                .foregroundColor(ILSTheme.Colors.textSecondary)
                                .padding(ILSTheme.Spacing.lg)
                                .frame(maxWidth: .infinity)
                        } else {
                            ForEach(filteredServers) { server in
                                MCPServerRow(server: server)
                            }
                        }
                    }
                    .padding(ILSTheme.Spacing.md)
                    .ilsCard()
                    
                    // Add New Server Section
                    VStack(alignment: .leading, spacing: ILSTheme.Spacing.sm) {
                        Text("Add New Server")
                            .font(ILSTheme.Typography.headline)
                            .foregroundColor(ILSTheme.Colors.textPrimary)
                        
                        Button(action: { showAddSheet = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(ILSTheme.Colors.accentPrimary)
                                Text("Add Custom MCP Server")
                                    .foregroundColor(ILSTheme.Colors.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(ILSTheme.Colors.textTertiary)
                            }
                            .padding(ILSTheme.Spacing.md)
                            .background(ILSTheme.Colors.backgroundTertiary)
                            .cornerRadius(ILSTheme.CornerRadius.small)
                        }
                    }
                    .padding(ILSTheme.Spacing.md)
                    .ilsCard()
                    
                    Spacer(minLength: ILSTheme.Spacing.xl)
                }
                .padding(.horizontal, ILSTheme.Spacing.lg)
                .padding(.top, ILSTheme.Spacing.md)
            }
            .background(ILSTheme.Colors.backgroundPrimary)
            .navigationTitle("MCP Servers")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(ILSTheme.Colors.accentPrimary)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddMCPServerView()
            }
        }
    }
}

struct MCPServerRow: View {
    let server: MCPServer
    @State private var showActions = false
    
    var statusColor: Color {
        switch server.status {
        case .healthy:
            return ILSTheme.Colors.success
        case .error:
            return ILSTheme.Colors.error
        case .unknown, .none:
            return ILSTheme.Colors.textTertiary
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: ILSTheme.Spacing.sm) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                
                Text(server.name)
                    .font(ILSTheme.Typography.headline)
                    .foregroundColor(ILSTheme.Colors.textPrimary)
                
                Spacer()
                
                if server.status == .error {
                    Text("(error)")
                        .font(ILSTheme.Typography.caption)
                        .foregroundColor(ILSTheme.Colors.error)
                }
            }
            
            Text("\(server.command) \(server.args.joined(separator: " "))")
                .font(ILSTheme.Typography.code)
                .foregroundColor(ILSTheme.Colors.textSecondary)
                .lineLimit(1)
            
            if !server.env.isEmpty {
                Text("Env: \(server.env.keys.joined(separator: ", "))")
                    .font(ILSTheme.Typography.caption)
                    .foregroundColor(ILSTheme.Colors.textTertiary)
            }
            
            HStack(spacing: ILSTheme.Spacing.sm) {
                if server.status == .error {
                    ActionButton(title: "Retry", icon: "arrow.clockwise") {}
                } else {
                    ActionButton(title: "Disable", icon: "pause.circle") {}
                }
                ActionButton(title: "Edit", icon: "pencil") {}
                ActionButton(title: "Delete", icon: "trash", isDestructive: true) {}
            }
        }
        .padding(ILSTheme.Spacing.md)
        .background(ILSTheme.Colors.backgroundTertiary)
        .cornerRadius(ILSTheme.CornerRadius.small)
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(title)
            }
            .font(ILSTheme.Typography.caption)
            .foregroundColor(isDestructive ? ILSTheme.Colors.error : ILSTheme.Colors.textSecondary)
            .padding(.horizontal, ILSTheme.Spacing.sm)
            .padding(.vertical, ILSTheme.Spacing.xs)
            .background(ILSTheme.Colors.backgroundSecondary)
            .cornerRadius(ILSTheme.CornerRadius.small)
        }
    }
}

struct AddMCPServerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var command = "npx"
    @State private var args = ""
    @State private var scope: MCPServer.ConfigScope = .user
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Server Details") {
                    TextField("Name", text: $name)
                    TextField("Command", text: $command)
                    TextField("Arguments (space separated)", text: $args)
                }
                
                Section("Scope") {
                    Picker("Scope", selection: $scope) {
                        Text("User").tag(MCPServer.ConfigScope.user)
                        Text("Project").tag(MCPServer.ConfigScope.project)
                        Text("Local").tag(MCPServer.ConfigScope.local)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(ILSTheme.Colors.backgroundPrimary)
            .navigationTitle("Add MCP Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") { dismiss() }
                        .disabled(name.isEmpty || command.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    MCPServerListView()
        .preferredColorScheme(.dark)
}
```

**Validation Criteria:**
- [ ] Build succeeds
- [ ] Simulator shows:
- "MCP Servers" navigation title
- Scope segmented control (User/Project/Local)
- Server rows with status indicators
- Green dot for healthy, red for error
- Command displayed in monospace font
- Action buttons (Disable/Retry, Edit, Delete)
- Add server section

**Evidence Required:**

```
EVIDENCE_3.4:
- Type: iOS Simulator Screenshot
- Shows: MCPServerListView
- Must Verify:
  - [ ] Segmented control visible
  - [ ] At least 2 server rows
  - [ ] Green status dot on github server
  - [ ] Red status dot on postgres server
  - [ ] Command text in monospace
  - [ ] Action buttons visible
- Filename: evidence_3.4_mcp_servers.png
- Status: PASS/FAIL
```

**BLOCKING:** Cannot proceed to 3.5 until screenshot shows PASS

---

### Task 3.5: Create PluginMarketplaceView

**Sub-Agent Assignment:** MAIN AGENT

**File:** `Sources/ILSApp/Views/Plugins/PluginMarketplaceView.swift`

```swift
import SwiftUI
import ILSShared

struct PluginMarketplaceView: View {
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    
    let categories = ["All", "Productivity", "DevOps", "Testing", "Documentation"]
    
    @State private var plugins: [Plugin] = [
        Plugin(
            name: "github",
            description: "GitHub integration plugin",
            marketplace: "claude-plugins-official",
            isInstalled: false,
            isEnabled: false,
            version: "1.0.0",
            stars: 2100,
            source: .official
        ),
        Plugin(
            name: "linear",
            description: "Linear project management integration",
            marketplace: "claude-plugins-official",
            isInstalled: false,
            isEnabled: false,
            version: "1.0.0",
            stars: 856,
            source: .official
        ),
        Plugin(
            name: "sentry",
            description: "Error tracking and monitoring integration",
            marketplace: "claude-plugins-official",
            isInstalled: true,
            isEnabled: true,
            version: "1.0.0",
            stars: 432,
            source: .official
        )
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ILSTheme.Spacing.lg) {
                    // Search Field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(ILSTheme.Colors.textSecondary)
                        
                        TextField("Search plugins...", text: $searchText)
                            .font(ILSTheme.Typography.body)
                            .foregroundColor(ILSTheme.Colors.textPrimary)
                    }
                    .padding(ILSTheme.Spacing.md)
                    .background(ILSTheme.Colors.backgroundTertiary)
                    .cornerRadius(ILSTheme.CornerRadius.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: ILSTheme.CornerRadius.small)
                            .stroke(ILSTheme.Colors.borderDefault, lineWidth: 1)
                    )
                    
                    // Categories
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: ILSTheme.Spacing.sm) {
                            ForEach(categories, id: \.self) { category in
                                CategoryPill(
                                    title: category,
                                    isSelected: selectedCategory == category
                                ) {
                                    selectedCategory = category
                                }
                            }
                        }
                    }
                    
                    // Official Marketplace Section
                    VStack(alignment: .leading, spacing: ILSTheme.Spacing.sm) {
                        HStack {
                            Text("Official Marketplace")
                                .font(ILSTheme.Typography.headline)
                                .foregroundColor(ILSTheme.Colors.textPrimary)
                            
                            Spacer()
                            
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(ILSTheme.Colors.accentPrimary)
                        }
                        
                        ForEach(plugins) { plugin in
                            PluginRow(plugin: plugin) {
                                // Install/uninstall action
                            }
                        }
                    }
                    .padding(ILSTheme.Spacing.md)
                    .ilsCard()
                    
                    // Add Custom Marketplace
                    VStack(alignment: .leading, spacing: ILSTheme.Spacing.sm) {
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(ILSTheme.Colors.accentPrimary)
                                Text("Add from GitHub repo")
                                    .foregroundColor(ILSTheme.Colors.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(ILSTheme.Colors.textTertiary)
                            }
                            .padding(ILSTheme.Spacing.md)
                            .background(ILSTheme.Colors.backgroundTertiary)
                            .cornerRadius(ILSTheme.CornerRadius.small)
                        }
                    }
                    .padding(ILSTheme.Spacing.md)
                    .ilsCard()
                    
                    Spacer(minLength: ILSTheme.Spacing.xl)
                }
                .padding(.horizontal, ILSTheme.Spacing.lg)
                .padding(.top, ILSTheme.Spacing.md)
            }
            .background(ILSTheme.Colors.backgroundPrimary)
            .navigationTitle("Plugin Marketplace")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct CategoryPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(ILSTheme.Typography.subheadline)
                .foregroundColor(isSelected ? .white : ILSTheme.Colors.textSecondary)
                .padding(.horizontal, ILSTheme.Spacing.md)
                .padding(.vertical, ILSTheme.Spacing.sm)
                .background(isSelected ? ILSTheme.Colors.accentPrimary : ILSTheme.Colors.backgroundTertiary)
                .cornerRadius(ILSTheme.CornerRadius.large)
        }
    }
}

struct PluginRow: View {
    let plugin: Plugin
    let onAction: () -> Void
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 32))
                .foregroundColor(ILSTheme.Colors.accentPrimary)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(plugin.name)
                        .font(ILSTheme.Typography.headline)
                        .foregroundColor(ILSTheme.Colors.textPrimary)
                    
                    if plugin.source == .official {
                        Text("Official")
                            .font(ILSTheme.Typography.caption)
                            .foregroundColor(ILSTheme.Colors.accentPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ILSTheme.Colors.accentPrimary.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                if let description = plugin.description {
                    Text(description)
                        .font(ILSTheme.Typography.body)
                        .foregroundColor(ILSTheme.Colors.textSecondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: ILSTheme.Spacing.sm) {
                    if let stars = plugin.stars {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(ILSTheme.Colors.warning)
                            Text("\(stars)")
                        }
                        .font(ILSTheme.Typography.caption)
                        .foregroundColor(ILSTheme.Colors.textSecondary)
                    }
                }
            }
            
            Spacer()
            
            if plugin.isInstalled {
                Text("✓ Installed")
                    .font(ILSTheme.Typography.caption)
                    .foregroundColor(ILSTheme.Colors.success)
                    .padding(.horizontal, ILSTheme.Spacing.md)
                    .padding(.vertical, ILSTheme.Spacing.sm)
                    .background(ILSTheme.Colors.success.opacity(0.2))
                    .cornerRadius(ILSTheme.CornerRadius.small)
            } else {
                Button("Install", action: onAction)
                    .font(ILSTheme.Typography.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, ILSTheme.Spacing.md)
                    .padding(.vertical, ILSTheme.Spacing.sm)
                    .background(ILSTheme.Colors.accentPrimary)
                    .cornerRadius(ILSTheme.CornerRadius.small)
            }
        }
        .padding(ILSTheme.Spacing.md)
        .background(ILSTheme.Colors.backgroundTertiary)
        .cornerRadius(ILSTheme.CornerRadius.small)
    }
}

#Preview {
    PluginMarketplaceView()
        .preferredColorScheme(.dark)
}
```

**Validation Criteria:**
- [ ] Build succeeds
- [ ] Simulator shows:
- Search field
- Category pills (All, Productivity, etc.)
- Official Marketplace section with checkmark seal
- 3 plugin rows
- Orange Install buttons
- Green "✓ Installed" badge for sentry
- Star counts

**Evidence Required:**

```
EVIDENCE_3.5:
- Type: iOS Simulator Screenshot
- Shows: PluginMarketplaceView
- Must Verify:
  - [ ] Search field present
  - [ ] Category pills visible
  - [ ] "Official Marketplace" with seal icon
  - [ ] github plugin with Install button
  - [ ] sentry plugin with "✓ Installed" badge
  - [ ] Star counts (2.1k, 856, 432)
- Filename: evidence_3.5_plugins.png
- Status: PASS/FAIL
```

**BLOCKING:** Cannot proceed to 3.6 until screenshot shows PASS

---

### Task 3.6: Create SettingsEditorView

**Sub-Agent Assignment:** MAIN AGENT

**File:** `Sources/ILSApp/Views/Settings/SettingsEditorView.swift`

```swift
import SwiftUI
import ILSShared

struct SettingsEditorView: View {
    @State private var selectedScope = "user"
    @State private var configText = """
{
  "model": "claude-sonnet-4-20250514",
  "permissions": {
    "allow": [
      "Bash(npm run *)"
    ],
    "deny": [
      "Read(.env)"
    ]
  },
  "env": {
    "DEBUG": "true"
  }
}
"""
    @State private var isValid = true
    @State private var validationMessage = "Valid JSON"
    @State private var showSaveConfirmation = false
    
    // Quick settings
    @State private var selectedModel = "claude-sonnet-4-20250514"
    @State private var extendedThinking = true
    @State private var coauthoredBy = false
    
    let models = ["claude-sonnet-4-20250514", "claude-opus-4-20250514", "claude-haiku-3-5-20241022"]
    let scopes = ["user", "project", "local"]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ILSTheme.Spacing.lg) {
                    // Scope Selector
                    HStack {
                        Text("Config File:")
                            .font(ILSTheme.Typography.body)
                            .foregroundColor(ILSTheme.Colors.textSecondary)
                        
                        Picker("Scope", selection: $selectedScope) {
                            Text("User").tag("user")
                            Text("Project").tag("project")
                            Text("Local").tag("local")
                        }
                        .pickerStyle(.menu)
                        .tint(ILSTheme.Colors.accentPrimary)
                    }
                    
                    // JSON Editor
                    VStack(alignment: .leading, spacing: ILSTheme.Spacing.sm) {
                        TextEditor(text: $configText)
                            .font(ILSTheme.Typography.code)
                            .foregroundColor(ILSTheme.Colors.textPrimary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 300)
                            .padding(ILSTheme.Spacing.md)
                            .background(ILSTheme.Colors.backgroundPrimary)
                            .cornerRadius(ILSTheme.CornerRadius.small)
                            .overlay(
                                RoundedRectangle(cornerRadius: ILSTheme.CornerRadius.small)
                                    .stroke(isValid ? ILSTheme.Colors.borderDefault : ILSTheme.Colors.error, lineWidth: 1)
                            )
                        
                        HStack {
                            Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(isValid ? ILSTheme.Colors.success : ILSTheme.Colors.error)
                            Text(validationMessage)
                                .font(ILSTheme.Typography.caption)
                                .foregroundColor(isValid ? ILSTheme.Colors.success : ILSTheme.Colors.error)
                        }
                    }
                    .padding(ILSTheme.Spacing.md)
                    .ilsCard()
                    
                    // Save Button
                    Button(action: { showSaveConfirmation = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save Changes")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ILSPrimaryButtonStyle())
                    .disabled(!isValid)
                    
                    // Quick Settings
                    VStack(alignment: .leading, spacing: ILSTheme.Spacing.md) {
                        Text("Quick Settings")
                            .font(ILSTheme.Typography.headline)
                            .foregroundColor(ILSTheme.Colors.textPrimary)
                        
                        // Model Picker
                        HStack {
                            Text("Model:")
                                .font(ILSTheme.Typography.body)
                                .foregroundColor(ILSTheme.Colors.textSecondary)
                            
                            Spacer()
                            
                            Picker("Model", selection: $selectedModel) {
                                ForEach(models, id: \.self) { model in
                                    Text(model.replacingOccurrences(of: "claude-", with: "").prefix(12) + "...")
                                        .tag(model)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(ILSTheme.Colors.accentPrimary)
                        }
                        
                        // Extended Thinking Toggle
                        Toggle(isOn: $extendedThinking) {
                            Text("Extended Thinking")
                                .font(ILSTheme.Typography.body)
                                .foregroundColor(ILSTheme.Colors.textPrimary)
                        }
                        .tint(ILSTheme.Colors.accentPrimary)
                        
                        // Co-authored-by Toggle
                        Toggle(isOn: $coauthoredBy) {
                            Text("Co-authored-by in commits")
                                .font(ILSTheme.Typography.body)
                                .foregroundColor(ILSTheme.Colors.textPrimary)
                        }
                        .tint(ILSTheme.Colors.accentPrimary)
                    }
                    .padding(ILSTheme.Spacing.md)
                    .ilsCard()
                    
                    Spacer(minLength: ILSTheme.Spacing.xl)
                }
                .padding(.horizontal, ILSTheme.Spacing.lg)
                .padding(.top, ILSTheme.Spacing.md)
            }
            .background(ILSTheme.Colors.backgroundPrimary)
            .navigationTitle("Claude Settings")
            .navigationBarTitleDisplayMode(.large)
            .alert("Save Changes", isPresented: $showSaveConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    // Save action
                }
            } message: {
                Text("This will update the \(selectedScope) settings file.")
            }
            .onChange(of: configText) { _, newValue in
                validateJSON(newValue)
            }
        }
    }
    
    private func validateJSON(_ text: String) {
        guard let data = text.data(using: .utf8) else {
            isValid = false
            validationMessage = "Invalid encoding"
            return
        }
        
        do {
            _ = try JSONSerialization.jsonObject(with: data)
            isValid = true
            validationMessage = "Valid JSON"
        } catch {
            isValid = false
            validationMessage = "Invalid JSON: \(error.localizedDescription)"
        }
    }
}

#Preview {
    SettingsEditorView()
        .preferredColorScheme(.dark)
}
```

**Validation Criteria:**
- [ ] Build succeeds
- [ ] Simulator shows:
- Scope picker (User/Project/Local)
- JSON editor with monospace font
- "✓ Valid JSON" indicator
- Orange "Save Changes" button
- Quick Settings section with:
  - Model dropdown
  - Extended Thinking toggle (orange when on)
  - Co-authored-by toggle

**Evidence Required:**

```
EVIDENCE_3.6:
- Type: iOS Simulator Screenshot
- Shows: SettingsEditorView
- Must Verify:
  - [ ] Scope picker visible
  - [ ] JSON text visible in editor
  - [ ] Green "Valid JSON" indicator
  - [ ] Save Changes button (orange)
  - [ ] Model picker shows claude-sonnet
  - [ ] Toggle switches visible
- Filename: evidence_3.6_settings.png
- Status: PASS/FAIL
```

**BLOCKING:** Cannot proceed to 3.7 until screenshot shows PASS

---

### Task 3.7: Create Main App Entry and Tab Navigation

**Sub-Agent Assignment:** MAIN AGENT

**File:** `Sources/ILSApp/ILSApp.swift`

```swift
import SwiftUI

@main
struct ILSApp: App {
    @State private var isConnected = false
    
    var body: some Scene {
        WindowGroup {
            if isConnected {
                MainTabView()
                    .preferredColorScheme(.dark)
            } else {
                ServerConnectionView()
                    .preferredColorScheme(.dark)
                    .onAppear {
                        // For testing, auto-connect after delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isConnected = true
                        }
                    }
            }
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            
            SkillsListView()
                .tabItem {
                    Image(systemName: "book.closed.fill")
                    Text("Skills")
                }
                .tag(1)
            
            MCPServerListView()
                .tabItem {
                    Image(systemName: "server.rack")
                    Text("MCPs")
                }
                .tag(2)
            
            PluginMarketplaceView()
                .tabItem {
                    Image(systemName: "puzzlepiece.fill")
                    Text("Plugins")
                }
                .tag(3)
            
            SettingsEditorView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .tag(4)
        }
        .tint(ILSTheme.Colors.accentPrimary)
    }
}

#Preview {
    MainTabView()
        .preferredColorScheme(.dark)
}
```

**Validation Criteria:**
- [ ] Build succeeds
- [ ] App launches in Simulator
- [ ] Tab bar visible at bottom with 5 tabs:
- Home (house icon)
- Skills (book icon)
- MCPs (server icon)
- Plugins (puzzle icon)
- Settings (gear icon)
- 
  - [ ] Tabs use orange accent color when selected
- 
  - [ ] All tabs navigate to correct views

**Evidence Required:**

```
EVIDENCE_3.7:
- Type: iOS Simulator Screenshot (2 screenshots)

Screenshot 1 - Dashboard Tab:
- Shows: MainTabView with Dashboard visible
- Must Verify:
  - [ ] Tab bar with 5 icons
  - [ ] Home tab selected (orange)
  - [ ] Dashboard content visible
- Filename: evidence_3.7a_tab_home.png

Screenshot 2 - Skills Tab:
- Shows: MainTabView with Skills tab selected
- Must Verify:
  - [ ] Skills tab selected (orange)
  - [ ] Skills list content visible
- Filename: evidence_3.7b_tab_skills.png

- Status: PASS/FAIL (both screenshots required)
```

---

### GATE CHECK 3: All Views Complete

```
GATE_CHECK_3:
- Task 3.1 (ServerConnectionView): PASS/FAIL - Evidence: evidence_3.1_server_connection.png
- Task 3.2 (DashboardView): PASS/FAIL - Evidence: evidence_3.2_dashboard.png
- Task 3.3 (SkillsListView + Detail): PASS/FAIL - Evidence: evidence_3.3a_skills_list.png, evidence_3.3b_skill_detail.png
- Task 3.4 (MCPServerListView): PASS/FAIL - Evidence: evidence_3.4_mcp_servers.png
- Task 3.5 (PluginMarketplaceView): PASS/FAIL - Evidence: evidence_3.5_plugins.png
- Task 3.6 (SettingsEditorView): PASS/FAIL - Evidence: evidence_3.6_settings.png
- Task 3.7 (MainTabView): PASS/FAIL - Evidence: evidence_3.7a_tab_home.png, evidence_3.7b_tab_skills.png

TOTAL SCREENSHOTS REQUIRED: 9
OVERALL: PASS only if ALL views have screenshot evidence showing PASS
```

&lt;/phase_3&gt;

---

## PHASE 4: Integration Testing

&lt;phase_4&gt;

### Task 4.1: Connect iOS App to Backend

**Sub-Agent Assignment:** MAIN AGENT

**File:** `Sources/ILSApp/Services/APIClient.swift`

```swift
import Foundation
import ILSShared

actor APIClient {
    static let shared = APIClient()
    
    private let baseURL: URL
    private let session: URLSession
    private var authToken: String?
    
    private init() {
        self.baseURL = URL(string: "http://localhost:8080/api/v1")!
        self.session = URLSession.shared
    }
    
    func setAuthToken(_ token: String) {
        self.authToken = token
    }
    
    // MARK: - Stats
    
    func fetchStats() async throws -> DashboardStats {
        let response: APIResponse<DashboardStats> = try await get(path: "/stats")
        guard let data = response.data else {
            throw APIClientError.noData
        }
        return data
    }
    
    // MARK: - Skills
    
    func fetchSkills() async throws -> [Skill] {
        let response: APIResponse<ListResponse<Skill>> = try await get(path: "/skills")
        return response.data?.items ?? []
    }
    
    func searchSkills(query: String) async throws -> [GitHubSearchResult] {
        let response: APIResponse<ListResponse<GitHubSearchResult>> = try await get(
            path: "/skills/search",
            queryItems: [URLQueryItem(name: "q", value: query)]
        )
        return response.data?.items ?? []
    }
    
    func installSkill(repository: String, skillPath: String?) async throws -> Skill {
        let request = SkillInstallRequest(repository: repository, skillPath: skillPath)
        let response: APIResponse<Skill> = try await post(path: "/skills/install", body: request)
        guard let skill = response.data else {
            throw APIClientError.noData
        }
        return skill
    }
    
    // MARK: - MCP
    
    func fetchMCPServers(scope: MCPServer.ConfigScope? = nil) async throws -> [MCPServer] {
        var queryItems: [URLQueryItem] = []
        if let scope = scope {
            queryItems.append(URLQueryItem(name: "scope", value: scope.rawValue))
        }
        let response: APIResponse<ListResponse<MCPServer>> = try await get(path: "/mcp", queryItems: queryItems)
        return response.data?.items ?? []
    }
    
    func createMCPServer(_ request: MCPServerCreateRequest) async throws -> MCPServer {
        let response: APIResponse<MCPServer> = try await post(path: "/mcp", body: request)
        guard let server = response.data else {
            throw APIClientError.noData
        }
        return server
    }
    
    // MARK: - Plugins
    
    func fetchPlugins() async throws -> [Plugin] {
        let response: APIResponse<ListResponse<Plugin>> = try await get(path: "/plugins")
        return response.data?.items ?? []
    }
    
    func fetchMarketplaces() async throws -> [Marketplace] {
        let response: APIResponse<ListResponse<Marketplace>> = try await get(path: "/plugins/marketplace")
        return response.data?.items ?? []
    }
    
    // MARK: - Config
    
    func fetchConfig(scope: String) async throws -> ClaudeConfig {
        let response: ConfigResponseDTO = try await get(
            path: "/config",
            queryItems: [URLQueryItem(name: "scope", value: scope)]
        )
        return response.content
    }
    
    // MARK: - Private Methods
    
    private func get<T: Decodable>(path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIClientError.badResponse
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
    
    private func post<T: Decodable, B: Encodable>(path: String, body: B) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIClientError.badResponse
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}

enum APIClientError: Error {
    case noData
    case badResponse
    case decodingError
}

struct ConfigResponseDTO: Decodable {
    let scope: String
    let path: String
    let content: ClaudeConfig
    let isValid: Bool
}
```

**Validation Criteria:**
- [ ] Build succeeds

---

### Task 4.2: Update DashboardView to Use Real API

**Sub-Agent Assignment:** MAIN AGENT

**Updated File:** `Sources/ILSApp/Views/Dashboard/DashboardView.swift`

Add at top of struct:

```swift
@State private var isLoading = true
@State private var errorMessage: String?
```

Add task to load data:

```swift
.task {
    await loadStats()
}

private func loadStats() async {
    isLoading = true
    do {
        stats = try await APIClient.shared.fetchStats()
        isLoading = false
    } catch {
        errorMessage = error.localizedDescription
        isLoading = false
    }
}
```

---

### Task 4.3: Integration Validation

**Actions:**
1. Start backend in Terminal 1:

```bash
cd ILSApp
swift run ILSBackend
```

1. Run iOS app in Simulator
2. Observe network traffic and verify data flows

**Validation Criteria:**
- [ ] Backend running and showing request logs
- [ ] iOS app Dashboard shows stats from API (not mock data)
- [ ] Backend logs show: `GET /api/v1/stats` request
- [ ] Evidence: Split screenshot showing:
- iOS Simulator with Dashboard
- Terminal with backend logs showing the request

**Evidence Required:**

```
EVIDENCE_4.3:
- Type: Correlated Screenshot
- Shows: 
  - LEFT: iOS Simulator with Dashboard showing stats
  - RIGHT: Terminal with Vapor backend logs

Backend Log Must Show:
  - Server started message
  - GET /api/v1/stats request logged

App Must Show:
  - Dashboard with stats (12 Skills, 8 MCPs, 3 Plugins)
  - Not showing loading state

- Filename: evidence_4.3_integration.png
- Status: PASS/FAIL
```

**BLOCKING:** Project not complete until this correlated evidence exists

---

### GATE CHECK 4: Integration Complete

```
GATE_CHECK_4:
- Backend compiles and runs: PASS/FAIL
- iOS app compiles and runs: PASS/FAIL
- API request logged in backend: PASS/FAIL
- Data displayed in iOS app matches API response: PASS/FAIL
- Correlated screenshot captured: PASS/FAIL

OVERALL: PASS only if ALL = PASS
```

&lt;/phase_4&gt;

---

## Evidence Checklist Summary

```
COMPLETE EVIDENCE MANIFEST:

Phase 0 - Environment Setup:
□ evidence_0.1 - Directory tree output
□ evidence_0.2 - Package resolve output
□ evidence_0.3 - Xcode setup screenshot

Phase 1 - Shared Models:
□ evidence_1.1 through 1.7 - Build outputs for each model file
□ GATE_CHECK_1 - Final shared models build

Phase 2A - Backend:
□ evidence_2a.1 through 2a.6 - Controller implementations
□ evidence_2a.7 - All cURL test outputs
□ GATE_CHECK_2A - All endpoints verified

Phase 2B - Design System:
□ evidence_2b.2 - Theme compilation
□ evidence_2b.3 - Theme preview screenshot
□ GATE_CHECK_2B - Design system complete

Phase 3 - iOS Views:
□ evidence_3.1 - ServerConnectionView screenshot
□ evidence_3.2 - DashboardView screenshot
□ evidence_3.3a - SkillsListView screenshot
□ evidence_3.3b - SkillDetailView screenshot
□ evidence_3.4 - MCPServerListView screenshot
□ evidence_3.5 - PluginMarketplaceView screenshot
□ evidence_3.6 - SettingsEditorView screenshot
□ evidence_3.7a - Tab navigation (Home)
□ evidence_3.7b - Tab navigation (Skills)
□ GATE_CHECK_3 - All 9 view screenshots collected

Phase 4 - Integration:
□ evidence_4.3 - Correlated backend + app screenshot
□ GATE_CHECK_4 - Full integration verified

TOTAL EVIDENCE ARTIFACTS REQUIRED: 20+
```

---

## Failure Recovery Protocol

&lt;failure_protocol&gt;
If ANY task fails validation:
1. **STOP** - Do not proceed to next task
2. **DIAGNOSE** - Read error messages completely
3. **FIX** - Make targeted corrections
4. **RE-VALIDATE** - Run the same validation again
5. **DOCUMENT** - Record what was fixed
6. **PROCEED** - Only after PASS status confirmed

If stuck in loop (3+ attempts):
1. Re-read all relevant code from scratch
2. Search for similar issues in documentation
3. Consider alternative implementation approach
4. Document the blocker for review

**NEVER:**
- Skip validation steps
- Proceed with "it probably works"
- Use mock data as real evidence
- Fake screenshots or terminal output
  &lt;/failure_protocol&gt;

---

## Final Success Criteria

```
PROJECT COMPLETE WHEN:
1. All 4 phases have PASS status
2. All 20+ evidence artifacts collected
3. Backend responds correctly to all endpoints (cURL verified)
4. All 7 iOS views render correctly (screenshot verified)
5. Integration shows correlated data flow (combined evidence)
6. Dark theme with hot orange accent throughout
7. No compilation warnings or errors
8. No mock data in final product
```