# ILS Application - Master Build Orchestration Specification

**Version**: 3.0 (Comprehensive Revision)
**Date**: 2026-02-01
**Methodology**: Evidence-Driven Development with Validation Gates

---

## System Directive

<system_directive>
You are an orchestration agent responsible for building the ILS (Intelligent Local Server) application. You MUST NOT proceed to any subsequent task until the current task's validation criteria are met with CONCRETE EVIDENCE. Evidence must include:
1. **For UI Tasks**: Screenshot from iOS Simulator showing the exact expected state
2. **For Backend Tasks**: Terminal output showing successful cURL response with expected JSON structure
3. **For Integration Tasks**: BOTH screenshot AND cURL output showing correlated data
4. **For Chat/Session Tasks**: Multiple screenshots showing streaming, tool execution, and response

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
</system_directive>

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
│   3.1 SidebarView → 3.2 SessionsListView → 3.3 NewSessionView →             │
│   3.4 ChatView → 3.5 MessageView → 3.6 ProjectsListView →                   │
│   3.7 PluginsListView → 3.8 MCPServerListView → 3.9 SettingsView            │
│                                                                              │
│   EACH VIEW: Code → Compile → Simulator Screenshot → THEN next view         │
└─────────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
                          ┌─────────────────┐
                          │  GATE CHECK 3   │
                          │ All views with  │
                          │ screenshots     │
                          └────────┬────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PHASE 4: CHAT/SESSION INTEGRATION                         │
│                              [SEQUENTIAL]                                    │
│                                                                              │
│   4.1 SSE Streaming → 4.2 Slash Commands → 4.3 Tool Execution →             │
│   4.4 Multi-turn Conversation → 4.5 Session Persistence                     │
│                                                                              │
│   EACH STEP: Screenshot series showing functionality                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
                          ┌─────────────────┐
                          │  GATE CHECK 4   │
                          │ Chat fully      │
                          │ functional      │
                          └────────┬────────┘
                                   │
                                   ▼
                            ┌─────────────┐
                            │  COMPLETE   │
                            └─────────────┘
```

---

## PHASE 0: Environment Setup

<phase_0>

### Task 0.1: Create Project Directory Structure

**Sub-Agent Assignment:** MAIN AGENT (no delegation)

**Actions:**

```bash
mkdir -p Sources/{ILSShared/Models,ILSShared/DTOs,ILSBackend/App,ILSBackend/Controllers,ILSBackend/Services,ILSBackend/Models,ILSBackend/Extensions}
mkdir -p ILSApp/ILSApp/{Theme,Views,ViewModels,Services}
mkdir -p ILSApp/ILSApp/Views/{Sidebar,Sessions,Chat,Projects,Plugins,MCP,Settings}
```

**Validation Criteria:**
- [ ] Run `tree Sources ILSApp -d` and capture terminal output
- [ ] Output must show ALL directories listed above
- [ ] Evidence: Terminal screenshot showing tree output

**Evidence Required:**

```
EVIDENCE_0.1:
- Type: Terminal Output
- Command: `tree Sources ILSApp -d`
- Expected: Directory tree matching specification
- Actual: [PASTE OUTPUT HERE]
- Timestamp: [YYYY-MM-DD HH:MM:SS]
- Status: PASS/FAIL
```

**BLOCKING:** Cannot proceed to 0.2 until PASS

---

### Task 0.2: Create Root Package.swift

**Sub-Agent Assignment:** MAIN AGENT

**File:** `Package.swift`

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
- Timestamp: [YYYY-MM-DD HH:MM:SS]
- Status: PASS/FAIL
```

**BLOCKING:** Cannot proceed to 0.3 until PASS

---

### Task 0.3: Create Xcode Project for iOS App

**Sub-Agent Assignment:** MAIN AGENT

**Actions:**
1. Create Xcode iOS App project "ILSApp" in ILSApp/ directory
2. Configure:
   - Interface: SwiftUI
   - Language: Swift
   - Minimum deployment: iOS 17.0
3. Add local package dependency to ILSShared
4. Add Info.plist entries for local network access

**Info.plist Additions:**
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>ILS needs to connect to local development servers</string>
<key>NSBonjourServices</key>
<array>
    <string>_http._tcp</string>
</array>
```

**Validation Criteria:**
- [ ] Xcode project opens without errors
- [ ] Build succeeds (⌘+B) with zero errors
- [ ] Simulator launches showing default ContentView
- [ ] Evidence: Screenshot of Xcode with successful build AND simulator showing app

**Evidence Required:**

```
EVIDENCE_0.3:
- Type: Screenshot
- Shows: Xcode build succeeded (green checkmark) + Simulator with app running
- Filename: evidence_0.3_xcode_setup.png
- Timestamp: [YYYY-MM-DD HH:MM:SS]
- Status: PASS/FAIL
```

**BLOCKING:** Cannot proceed to Phase 1 until PASS

</phase_0>

---

## PHASE 1: Shared Models Package

<phase_1>

### Task 1.1: Create Session and Project Models

**Sub-Agent Assignment:** MAIN AGENT

**File:** `Sources/ILSShared/Models/Session.swift`

```swift
import Foundation

/// A chat session with Claude - renamed to avoid Foundation.URLSession conflict
public struct ChatSession: Codable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public var claudeSessionId: String?
    public var name: String?
    public var projectId: UUID?
    public var projectName: String?
    public var model: String
    public var permissionMode: PermissionMode
    public var status: SessionStatus
    public var messageCount: Int
    public var totalCostUSD: Double?
    public var source: SessionSource
    public var createdAt: Date
    public var lastActiveAt: Date

    public init(
        id: UUID = UUID(),
        claudeSessionId: String? = nil,
        name: String? = nil,
        projectId: UUID? = nil,
        projectName: String? = nil,
        model: String = "sonnet",
        permissionMode: PermissionMode = .default,
        status: SessionStatus = .active,
        messageCount: Int = 0,
        totalCostUSD: Double? = nil,
        source: SessionSource = .ils,
        createdAt: Date = Date(),
        lastActiveAt: Date = Date()
    ) {
        self.id = id
        self.claudeSessionId = claudeSessionId
        self.name = name
        self.projectId = projectId
        self.projectName = projectName
        self.model = model
        self.permissionMode = permissionMode
        self.status = status
        self.messageCount = messageCount
        self.totalCostUSD = totalCostUSD
        self.source = source
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
    }
}

public enum SessionStatus: String, Codable, Sendable {
    case active
    case completed
    case cancelled
    case error
}

public enum SessionSource: String, Codable, Sendable {
    case ils       // Created by ILS app
    case external  // Discovered from ~/.claude/projects/
}

public enum PermissionMode: String, Codable, Sendable, CaseIterable {
    case `default` = "default"
    case acceptEdits = "acceptEdits"
    case bypassPermissions = "bypassPermissions"
    case planMode = "planMode"

    public var displayName: String {
        switch self {
        case .default: return "Default"
        case .acceptEdits: return "Accept Edits"
        case .bypassPermissions: return "Bypass Permissions"
        case .planMode: return "Plan Mode"
        }
    }
}
```

**File:** `Sources/ILSShared/Models/Project.swift`

```swift
import Foundation

public struct Project: Codable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public var name: String
    public var path: String
    public var defaultModel: String?
    public var description: String?
    public var createdAt: Date
    public var lastAccessedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        path: String,
        defaultModel: String? = nil,
        description: String? = nil,
        createdAt: Date = Date(),
        lastAccessedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.defaultModel = defaultModel
        self.description = description
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
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
- Timestamp: [YYYY-MM-DD HH:MM:SS]
- Status: PASS/FAIL
```

**BLOCKING:** Cannot proceed to 1.2 until PASS

---

### Task 1.2: Create StreamMessage Models for SSE/Chat

**Sub-Agent Assignment:** MAIN AGENT

**File:** `Sources/ILSShared/Models/StreamMessage.swift`

```swift
import Foundation

// MARK: - Stream Message Types

/// Top-level message received from SSE stream
public enum StreamMessage: Codable, Sendable {
    case system(SystemMessage)
    case assistant(AssistantMessage)
    case user(UserMessage)
    case result(ResultMessage)

    enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "system":
            self = .system(try SystemMessage(from: decoder))
        case "assistant":
            self = .assistant(try AssistantMessage(from: decoder))
        case "user":
            self = .user(try UserMessage(from: decoder))
        case "result":
            self = .result(try ResultMessage(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown message type: \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .system(let msg):
            try msg.encode(to: encoder)
        case .assistant(let msg):
            try msg.encode(to: encoder)
        case .user(let msg):
            try msg.encode(to: encoder)
        case .result(let msg):
            try msg.encode(to: encoder)
        }
    }
}

// MARK: - System Message

public struct SystemMessage: Codable, Sendable {
    public let type: String
    public let subtype: String
    public let data: SystemData

    public struct SystemData: Codable, Sendable {
        public let sessionId: String?
        public let plugins: [String]?
        public let slashCommands: [String]?
    }
}

// MARK: - Assistant Message

public struct AssistantMessage: Codable, Sendable, Identifiable {
    public var id: UUID { UUID() }
    public let type: String
    public let content: [ContentBlock]
    public let costUSD: Double?
    public let durationMs: Int?

    public init(type: String = "assistant", content: [ContentBlock], costUSD: Double? = nil, durationMs: Int? = nil) {
        self.type = type
        self.content = content
        self.costUSD = costUSD
        self.durationMs = durationMs
    }
}

// MARK: - Content Blocks

public enum ContentBlock: Codable, Sendable, Identifiable {
    case text(TextBlock)
    case toolUse(ToolUseBlock)
    case toolResult(ToolResultBlock)
    case thinking(ThinkingBlock)

    public var id: String {
        switch self {
        case .text(let block): return block.id
        case .toolUse(let block): return block.id
        case .toolResult(let block): return block.id
        case .thinking(let block): return block.id
        }
    }

    enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            self = .text(try TextBlock(from: decoder))
        case "tool_use", "toolUse":
            self = .toolUse(try ToolUseBlock(from: decoder))
        case "tool_result", "toolResult":
            self = .toolResult(try ToolResultBlock(from: decoder))
        case "thinking":
            self = .thinking(try ThinkingBlock(from: decoder))
        default:
            // Default to text for unknown types
            self = .text(TextBlock(text: "[Unknown content type: \(type)]"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let block):
            try block.encode(to: encoder)
        case .toolUse(let block):
            try block.encode(to: encoder)
        case .toolResult(let block):
            try block.encode(to: encoder)
        case .thinking(let block):
            try block.encode(to: encoder)
        }
    }
}

public struct TextBlock: Codable, Sendable, Identifiable {
    public let id: String
    public let type: String
    public let text: String

    public init(id: String = UUID().uuidString, text: String) {
        self.id = id
        self.type = "text"
        self.text = text
    }
}

public struct ToolUseBlock: Codable, Sendable, Identifiable {
    public let id: String
    public let type: String
    public let name: String
    public let input: AnyCodable

    public init(id: String, name: String, input: AnyCodable) {
        self.id = id
        self.type = "tool_use"
        self.name = name
        self.input = input
    }
}

public struct ToolResultBlock: Codable, Sendable, Identifiable {
    public let id: String
    public let type: String
    public let toolUseId: String
    public let content: String
    public let isError: Bool

    public init(id: String = UUID().uuidString, toolUseId: String, content: String, isError: Bool = false) {
        self.id = id
        self.type = "tool_result"
        self.toolUseId = toolUseId
        self.content = content
        self.isError = isError
    }
}

public struct ThinkingBlock: Codable, Sendable, Identifiable {
    public let id: String
    public let type: String
    public let thinking: String

    public init(id: String = UUID().uuidString, thinking: String) {
        self.id = id
        self.type = "thinking"
        self.thinking = thinking
    }
}

// MARK: - User Message

public struct UserMessage: Codable, Sendable {
    public let type: String
    public let content: String

    public init(content: String) {
        self.type = "user"
        self.content = content
    }
}

// MARK: - Result Message

public struct ResultMessage: Codable, Sendable {
    public let type: String
    public let subtype: String
    public let sessionId: String?
    public let durationMs: Int?
    public let durationApiMs: Int?
    public let isError: Bool
    public let numTurns: Int?
    public let totalCostUSD: Double?
    public let usage: UsageInfo?

    public struct UsageInfo: Codable, Sendable {
        public let inputTokens: Int
        public let outputTokens: Int
    }
}

// MARK: - AnyCodable Helper

public struct AnyCodable: Codable, Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode AnyCodable")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Cannot encode AnyCodable"))
        }
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
- Timestamp: [YYYY-MM-DD HH:MM:SS]
- Status: PASS/FAIL
```

**BLOCKING:** Cannot proceed to 1.3 until PASS

---

### Task 1.3: Create Skill Model with YAML Parsing

**Sub-Agent Assignment:** MAIN AGENT

**File:** `Sources/ILSShared/Models/Skill.swift`

```swift
import Foundation
import Yams

public struct Skill: Codable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public var name: String
    public var description: String
    public var version: String?
    public var isActive: Bool
    public var path: String
    public var rawContent: String
    public var source: SkillSource?

    public enum SkillSource: Codable, Sendable, Hashable {
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

        public init(name: String, description: String, instructions: String) {
            self.name = name
            self.description = description
            self.instructions = instructions
        }
    }

    public enum ParseError: Error, LocalizedError {
        case noFrontmatter
        case invalidYAML(String)
        case missingRequiredField(String)

        public var errorDescription: String? {
            switch self {
            case .noFrontmatter:
                return "No YAML frontmatter found"
            case .invalidYAML(let detail):
                return "Invalid YAML: \(detail)"
            case .missingRequiredField(let field):
                return "Missing required field: \(field)"
            }
        }
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

    public static func generateContent(name: String, description: String, instructions: String) -> String {
        """
        ---
        name: \(name)
        description: \(description)
        ---
        \(instructions)
        """
    }

    public init() {}
}
```

**Validation Criteria:**
- [ ] Run `swift build --target ILSShared`
- [ ] Build succeeds with zero errors

**Evidence Required:**

```
EVIDENCE_1.3:
- Type: Terminal Output
- Command: `swift build --target ILSShared`
- Expected: "Build complete!"
- Actual: [PASTE OUTPUT]
- Timestamp: [YYYY-MM-DD HH:MM:SS]
- Status: PASS/FAIL
```

**BLOCKING:** Cannot proceed to 1.4 until PASS

---

### Task 1.4: Create MCPServer and Plugin Models

**Sub-Agent Assignment:** MAIN AGENT

**File:** `Sources/ILSShared/Models/MCPServer.swift`

```swift
import Foundation

public struct MCPServer: Codable, Identifiable, Sendable, Hashable {
    public var id: String { name }
    public let name: String
    public var command: String
    public var args: [String]
    public var env: [String: String]
    public var scope: ConfigScope
    public var status: ServerStatus?
    public var configPath: String?

    public enum ConfigScope: String, Codable, Sendable, CaseIterable {
        case user
        case project
        case local
        case managed

        public var displayName: String {
            switch self {
            case .user: return "User"
            case .project: return "Project"
            case .local: return "Local"
            case .managed: return "Managed"
            }
        }
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
        status: ServerStatus? = nil,
        configPath: String? = nil
    ) {
        self.name = name
        self.command = command
        self.args = args
        self.env = env
        self.scope = scope
        self.status = status
        self.configPath = configPath
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

**File:** `Sources/ILSShared/Models/Plugin.swift`

```swift
import Foundation

public struct Plugin: Codable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public var name: String
    public var description: String?
    public var marketplace: String
    public var isInstalled: Bool
    public var isEnabled: Bool
    public var version: String?
    public var stars: Int?
    public var source: PluginSource
    public var commands: [String]?
    public var agents: [String]?

    public enum PluginSource: Codable, Sendable, Hashable {
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
        source: PluginSource = .official,
        commands: [String]? = nil,
        agents: [String]? = nil
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
        self.commands = commands
        self.agents = agents
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

public struct Marketplace: Codable, Identifiable, Sendable, Hashable {
    public var id: String { name }
    public var name: String
    public var owner: MarketplaceOwner?
    public var plugins: [MarketplacePlugin]
    public var source: String

    public init(name: String, owner: MarketplaceOwner? = nil, plugins: [MarketplacePlugin] = [], source: String) {
        self.name = name
        self.owner = owner
        self.plugins = plugins
        self.source = source
    }
}

public struct MarketplaceOwner: Codable, Sendable, Hashable {
    public var name: String
    public var url: String?

    public init(name: String, url: String? = nil) {
        self.name = name
        self.url = url
    }
}

public struct MarketplacePlugin: Codable, Identifiable, Sendable, Hashable {
    public var id: String { name }
    public var name: String
    public var source: PluginSourceDefinition

    public init(name: String, source: PluginSourceDefinition) {
        self.name = name
        self.source = source
    }
}

public struct PluginSourceDefinition: Codable, Sendable, Hashable {
    public var type: String
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

**Evidence Required:**

```
EVIDENCE_1.4:
- Type: Terminal Output
- Command: `swift build --target ILSShared`
- Expected: "Build complete!"
- Actual: [PASTE OUTPUT]
- Timestamp: [YYYY-MM-DD HH:MM:SS]
- Status: PASS/FAIL
```

**BLOCKING:** Cannot proceed to 1.5 until PASS

---

### Task 1.5: Create ClaudeConfig Model

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
    public var preToolUse: [HookDefinition]?
    public var postToolUse: [HookDefinition]?

    public init(preToolUse: [HookDefinition]? = nil, postToolUse: [HookDefinition]? = nil) {
        self.preToolUse = preToolUse
        self.postToolUse = postToolUse
    }
}

public struct HookDefinition: Codable, Sendable {
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
    public static let pluginsCache = "~/.claude/plugins/cache"
    public static let projectsDirectory = "~/.claude/projects"

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

**Evidence Required:**

```
EVIDENCE_1.5:
- Type: Terminal Output
- Command: `swift build --target ILSShared`
- Expected: "Build complete!"
- Actual: [PASTE OUTPUT]
- Timestamp: [YYYY-MM-DD HH:MM:SS]
- Status: PASS/FAIL
```

**BLOCKING:** Cannot proceed to 1.6 until PASS

---

### Task 1.6: Create API DTOs

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
    public let sessions: ResourceStats
    public let projects: ResourceStats
    public let skills: ResourceStats
    public let mcpServers: ResourceStats
    public let plugins: ResourceStats

    public init(
        sessions: ResourceStats,
        projects: ResourceStats,
        skills: ResourceStats,
        mcpServers: ResourceStats,
        plugins: ResourceStats
    ) {
        self.sessions = sessions
        self.projects = projects
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
```

**File:** `Sources/ILSShared/DTOs/Requests.swift`

```swift
import Foundation

// MARK: - Project Requests

public struct CreateProjectRequest: Codable, Sendable {
    public let name: String
    public let path: String
    public let defaultModel: String?
    public let description: String?

    public init(name: String, path: String, defaultModel: String? = nil, description: String? = nil) {
        self.name = name
        self.path = path
        self.defaultModel = defaultModel
        self.description = description
    }
}

public struct UpdateProjectRequest: Codable, Sendable {
    public let name: String?
    public let defaultModel: String?
    public let description: String?

    public init(name: String? = nil, defaultModel: String? = nil, description: String? = nil) {
        self.name = name
        self.defaultModel = defaultModel
        self.description = description
    }
}

// MARK: - Session Requests

public struct CreateSessionRequest: Codable, Sendable {
    public let projectId: UUID?
    public let name: String?
    public let model: String
    public let permissionMode: PermissionMode

    public init(projectId: UUID? = nil, name: String? = nil, model: String = "sonnet", permissionMode: PermissionMode = .default) {
        self.projectId = projectId
        self.name = name
        self.model = model
        self.permissionMode = permissionMode
    }
}

// MARK: - Chat Requests

public struct ChatRequest: Codable, Sendable {
    public let prompt: String
    public let sessionId: UUID?
    public let projectId: UUID?
    public let options: ChatOptions?

    public init(prompt: String, sessionId: UUID? = nil, projectId: UUID? = nil, options: ChatOptions? = nil) {
        self.prompt = prompt
        self.sessionId = sessionId
        self.projectId = projectId
        self.options = options
    }
}

public struct ChatOptions: Codable, Sendable {
    public let model: String?
    public let permissionMode: PermissionMode?
    public let maxTurns: Int?
    public let allowedTools: [String]?
    public let disallowedTools: [String]?

    public init(
        model: String? = nil,
        permissionMode: PermissionMode? = nil,
        maxTurns: Int? = nil,
        allowedTools: [String]? = nil,
        disallowedTools: [String]? = nil
    ) {
        self.model = model
        self.permissionMode = permissionMode
        self.maxTurns = maxTurns
        self.allowedTools = allowedTools
        self.disallowedTools = disallowedTools
    }
}

// MARK: - Skill Requests

public struct CreateSkillRequest: Codable, Sendable {
    public let name: String
    public let description: String
    public let content: String

    public init(name: String, description: String, content: String) {
        self.name = name
        self.description = description
        self.content = content
    }
}

public struct UpdateSkillRequest: Codable, Sendable {
    public let content: String

    public init(content: String) {
        self.content = content
    }
}

// MARK: - MCP Requests

public struct CreateMCPServerRequest: Codable, Sendable {
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

// MARK: - Plugin Requests

public struct InstallPluginRequest: Codable, Sendable {
    public let pluginName: String
    public let marketplace: String
    public let scope: MCPServer.ConfigScope

    public init(pluginName: String, marketplace: String, scope: MCPServer.ConfigScope = .user) {
        self.pluginName = pluginName
        self.marketplace = marketplace
        self.scope = scope
    }
}

// MARK: - Config Requests

public struct UpdateConfigRequest: Codable, Sendable {
    public let scope: String
    public let content: ClaudeConfig

    public init(scope: String, content: ClaudeConfig) {
        self.scope = scope
        self.content = content
    }
}

public struct ValidateConfigRequest: Codable, Sendable {
    public let content: String

    public init(content: String) {
        self.content = content
    }
}
```

**Validation Criteria:**
- [ ] Run `swift build --target ILSShared`
- [ ] Build succeeds
- [ ] `ls Sources/ILSShared/**/*.swift | wc -l` shows 8+ files

**Evidence Required:**

```
EVIDENCE_1.6:
- Type: Terminal Output
- Command: `swift build --target ILSShared`
- Expected: "Build complete!"
- Actual: [PASTE OUTPUT]
- Timestamp: [YYYY-MM-DD HH:MM:SS]
- Status: PASS/FAIL
```

---

### GATE CHECK 1: Shared Models Complete

**Validation:**
- [ ] Run `swift build --target ILSShared` from project root
- [ ] Zero errors, zero warnings
- [ ] All model files exist and compile

**Evidence Required:**

```
GATE_CHECK_1:
- Command: `swift build --target ILSShared 2>&1`
- Expected: "Build complete!" with no errors
- Actual: [PASTE FULL OUTPUT]
- File Count: `ls Sources/ILSShared/**/*.swift | wc -l` = [NUMBER]
- Timestamp: [YYYY-MM-DD HH:MM:SS]
- Status: PASS/FAIL
```

**BLOCKING:** PHASE 2 CANNOT START until Gate Check 1 = PASS

</phase_1>

---

## PHASE 2A: Vapor Backend (SUB-AGENT ALPHA)

<phase_2a>

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
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith]
    )
    app.middleware.use(CORSMiddleware(configuration: corsConfiguration))

    // Database - SQLite for persistence
    app.databases.use(.sqlite(.file("ils.sqlite")), as: .sqlite)

    // Migrations
    app.migrations.add(CreateProject())
    app.migrations.add(CreateSession())

    try await app.autoMigrate()

    // Routes
    try routes(app)

    app.logger.info("ILS Backend configured successfully on port 8080")
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
    try api.register(collection: ProjectsController())
    try api.register(collection: SessionsController())
    try api.register(collection: ChatController())
    try api.register(collection: SkillsController())
    try api.register(collection: MCPController())
    try api.register(collection: PluginsController())
    try api.register(collection: ConfigController())
    try api.register(collection: StatsController())
}
```

**Validation Criteria:**
- [ ] Files created at correct paths
- [ ] Syntax valid (will verify compilation after controllers created)

---

### Task 2A.2: Create Database Models and Migrations

**Sub-Agent Assignment:** ALPHA

**File:** `Sources/ILSBackend/Models/ProjectModel.swift`

```swift
import Fluent
import Vapor
import ILSShared

final class ProjectModel: Model, Content, @unchecked Sendable {
    static let schema = "projects"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "path")
    var path: String

    @OptionalField(key: "default_model")
    var defaultModel: String?

    @OptionalField(key: "description")
    var description: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "last_accessed_at", on: .update)
    var lastAccessedAt: Date?

    init() {}

    init(id: UUID? = nil, name: String, path: String, defaultModel: String? = nil, description: String? = nil) {
        self.id = id
        self.name = name
        self.path = path
        self.defaultModel = defaultModel
        self.description = description
    }

    func toDTO() -> Project {
        Project(
            id: id ?? UUID(),
            name: name,
            path: path,
            defaultModel: defaultModel,
            description: description,
            createdAt: createdAt ?? Date(),
            lastAccessedAt: lastAccessedAt ?? Date()
        )
    }

    static func from(_ dto: Project) -> ProjectModel {
        ProjectModel(
            id: dto.id,
            name: dto.name,
            path: dto.path,
            defaultModel: dto.defaultModel,
            description: dto.description
        )
    }
}

struct CreateProject: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("projects")
            .id()
            .field("name", .string, .required)
            .field("path", .string, .required)
            .field("default_model", .string)
            .field("description", .string)
            .field("created_at", .datetime)
            .field("last_accessed_at", .datetime)
            .unique(on: "path")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("projects").delete()
    }
}
```

**File:** `Sources/ILSBackend/Models/SessionModel.swift`

```swift
import Fluent
import Vapor
import ILSShared

final class SessionModel: Model, Content, @unchecked Sendable {
    static let schema = "sessions"

    @ID(key: .id)
    var id: UUID?

    @OptionalField(key: "claude_session_id")
    var claudeSessionId: String?

    @OptionalField(key: "name")
    var name: String?

    @OptionalParent(key: "project_id")
    var project: ProjectModel?

    @Field(key: "model")
    var model: String

    @Field(key: "permission_mode")
    var permissionMode: String

    @Field(key: "status")
    var status: String

    @Field(key: "message_count")
    var messageCount: Int

    @OptionalField(key: "total_cost_usd")
    var totalCostUSD: Double?

    @Field(key: "source")
    var source: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "last_active_at", on: .update)
    var lastActiveAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        claudeSessionId: String? = nil,
        name: String? = nil,
        projectId: UUID? = nil,
        model: String = "sonnet",
        permissionMode: String = "default",
        status: String = "active",
        messageCount: Int = 0,
        totalCostUSD: Double? = nil,
        source: String = "ils"
    ) {
        self.id = id
        self.claudeSessionId = claudeSessionId
        self.name = name
        self.$project.id = projectId
        self.model = model
        self.permissionMode = permissionMode
        self.status = status
        self.messageCount = messageCount
        self.totalCostUSD = totalCostUSD
        self.source = source
    }

    func toDTO(projectName: String? = nil) -> ChatSession {
        ChatSession(
            id: id ?? UUID(),
            claudeSessionId: claudeSessionId,
            name: name,
            projectId: $project.id,
            projectName: projectName,
            model: model,
            permissionMode: PermissionMode(rawValue: permissionMode) ?? .default,
            status: SessionStatus(rawValue: status) ?? .active,
            messageCount: messageCount,
            totalCostUSD: totalCostUSD,
            source: SessionSource(rawValue: source) ?? .ils,
            createdAt: createdAt ?? Date(),
            lastActiveAt: lastActiveAt ?? Date()
        )
    }

    static func from(_ dto: ChatSession) -> SessionModel {
        SessionModel(
            id: dto.id,
            claudeSessionId: dto.claudeSessionId,
            name: dto.name,
            projectId: dto.projectId,
            model: dto.model,
            permissionMode: dto.permissionMode.rawValue,
            status: dto.status.rawValue,
            messageCount: dto.messageCount,
            totalCostUSD: dto.totalCostUSD,
            source: dto.source.rawValue
        )
    }
}

struct CreateSession: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("sessions")
            .id()
            .field("claude_session_id", .string)
            .field("name", .string)
            .field("project_id", .uuid, .references("projects", "id", onDelete: .setNull))
            .field("model", .string, .required)
            .field("permission_mode", .string, .required)
            .field("status", .string, .required)
            .field("message_count", .int, .required)
            .field("total_cost_usd", .double)
            .field("source", .string, .required)
            .field("created_at", .datetime)
            .field("last_active_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("sessions").delete()
    }
}
```

**Validation Criteria:**
- [ ] Models compile correctly
- [ ] Migration syntax valid

---

### Task 2A.3: Create ClaudeExecutorService

**Sub-Agent Assignment:** ALPHA

**File:** `Sources/ILSBackend/Services/ClaudeExecutorService.swift`

```swift
import Foundation
import Vapor

/// Service for executing Claude CLI commands
actor ClaudeExecutorService {
    static let shared = ClaudeExecutorService()

    private init() {}

    /// Execute claude command and stream output
    func execute(
        prompt: String,
        workingDirectory: String? = nil,
        model: String = "sonnet",
        permissionMode: String = "default",
        sessionId: String? = nil,
        onOutput: @escaping (String) async -> Void
    ) async throws -> ClaudeResult {
        var args = ["--print", "--output-format", "stream-json"]

        // Add model
        args.append(contentsOf: ["--model", model])

        // Add permission mode
        switch permissionMode {
        case "acceptEdits":
            args.append("--allowedTools")
            args.append("Edit,Write,MultiEdit")
        case "bypassPermissions":
            args.append("--dangerouslySkipPermissions")
        case "planMode":
            args.append("--plan")
        default:
            break
        }

        // Resume session if provided
        if let sessionId = sessionId {
            args.append(contentsOf: ["--resume", sessionId])
        }

        // Add prompt
        args.append(contentsOf: ["--prompt", prompt])

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/claude")
        process.arguments = args

        if let workingDirectory = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        }

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        var outputData = Data()
        var sessionIdFromOutput: String?
        var totalCost: Double = 0

        // Handle output asynchronously
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            outputData.append(data)

            if let line = String(data: data, encoding: .utf8) {
                Task {
                    await onOutput(line)
                }

                // Extract session ID and cost from result messages
                if line.contains("\"type\":\"system\"") && line.contains("\"sessionId\"") {
                    if let range = line.range(of: "\"sessionId\":\"([^\"]+)\"", options: .regularExpression) {
                        let match = line[range]
                        let idStart = match.index(match.startIndex, offsetBy: 13)
                        let idEnd = match.index(match.endIndex, offsetBy: -1)
                        sessionIdFromOutput = String(match[idStart..<idEnd])
                    }
                }

                if line.contains("\"totalCostUSD\"") {
                    if let range = line.range(of: "\"totalCostUSD\":\\s*([0-9.]+)", options: .regularExpression) {
                        let match = line[range]
                        if let colonIndex = match.firstIndex(of: ":") {
                            let valueStart = match.index(after: colonIndex)
                            if let cost = Double(match[valueStart...].trimmingCharacters(in: .whitespaces)) {
                                totalCost = cost
                            }
                        }
                    }
                }
            }
        }

        try process.run()
        process.waitUntilExit()

        outputPipe.fileHandleForReading.readabilityHandler = nil

        return ClaudeResult(
            exitCode: Int(process.terminationStatus),
            sessionId: sessionIdFromOutput,
            totalCostUSD: totalCost,
            output: String(data: outputData, encoding: .utf8) ?? ""
        )
    }

    /// Check if Claude CLI is installed
    func isInstalled() -> Bool {
        FileManager.default.fileExists(atPath: "/usr/local/bin/claude")
    }

    /// Get Claude CLI version
    func version() async throws -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/claude")
        process.arguments = ["--version"]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ClaudeResult {
    let exitCode: Int
    let sessionId: String?
    let totalCostUSD: Double
    let output: String

    var isSuccess: Bool { exitCode == 0 }
}
```

**Validation Criteria:**
- [ ] File compiles
- [ ] Claude CLI path is correct for system

---

### Task 2A.4: Create StreamingService

**Sub-Agent Assignment:** ALPHA

**File:** `Sources/ILSBackend/Services/StreamingService.swift`

```swift
import Vapor
import ILSShared

/// Service for formatting and sending SSE events
struct StreamingService {

    /// Format a message as an SSE event
    static func formatSSE(event: String, data: String) -> String {
        var result = ""
        if !event.isEmpty {
            result += "event: \(event)\n"
        }
        // Split data by newlines and prefix each with "data: "
        let lines = data.split(separator: "\n", omittingEmptySubsequences: false)
        for line in lines {
            result += "data: \(line)\n"
        }
        result += "\n"
        return result
    }

    /// Format a StreamMessage as SSE
    static func formatMessage(_ message: StreamMessage) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(message)
        let jsonString = String(data: data, encoding: .utf8) ?? "{}"

        let eventType: String
        switch message {
        case .system:
            eventType = "system"
        case .assistant:
            eventType = "assistant"
        case .user:
            eventType = "user"
        case .result:
            eventType = "result"
        }

        return formatSSE(event: eventType, data: jsonString)
    }

    /// Create a system init message
    static func systemInit(sessionId: String, plugins: [String] = [], slashCommands: [String] = []) -> StreamMessage {
        .system(SystemMessage(
            type: "system",
            subtype: "init",
            data: SystemMessage.SystemData(
                sessionId: sessionId,
                plugins: plugins,
                slashCommands: slashCommands
            )
        ))
    }

    /// Create an assistant text message
    static func assistantText(_ text: String) -> StreamMessage {
        .assistant(AssistantMessage(
            content: [.text(TextBlock(text: text))]
        ))
    }

    /// Create a result message
    static func result(sessionId: String, durationMs: Int, costUSD: Double, inputTokens: Int, outputTokens: Int) -> StreamMessage {
        .result(ResultMessage(
            type: "result",
            subtype: "success",
            sessionId: sessionId,
            durationMs: durationMs,
            durationApiMs: durationMs,
            isError: false,
            numTurns: 1,
            totalCostUSD: costUSD,
            usage: ResultMessage.UsageInfo(inputTokens: inputTokens, outputTokens: outputTokens)
        ))
    }
}
```

**Validation Criteria:**
- [ ] File compiles

---

### Task 2A.5: Create All Controllers

**Sub-Agent Assignment:** ALPHA

**This task creates all 8 controllers. Each must compile before proceeding.**

**File:** `Sources/ILSBackend/Controllers/ProjectsController.swift`

```swift
import Vapor
import Fluent
import ILSShared

struct ProjectsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let projects = routes.grouped("projects")
        projects.get(use: list)
        projects.post(use: create)
        projects.get(":id", use: get)
        projects.put(":id", use: update)
        projects.delete(":id", use: delete)
        projects.get(":id", "sessions", use: getSessions)
    }

    @Sendable
    func list(req: Request) async throws -> APIResponse<ListResponse<Project>> {
        let projects = try await ProjectModel.query(on: req.db).all()
        let dtos = projects.map { $0.toDTO() }
        return .success(ListResponse(items: dtos))
    }

    @Sendable
    func create(req: Request) async throws -> APIResponse<Project> {
        let request = try req.content.decode(CreateProjectRequest.self)

        let project = ProjectModel(
            name: request.name,
            path: request.path,
            defaultModel: request.defaultModel,
            description: request.description
        )

        try await project.save(on: req.db)
        return .success(project.toDTO())
    }

    @Sendable
    func get(req: Request) async throws -> APIResponse<Project> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid project ID")
        }

        guard let project = try await ProjectModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Project not found")
        }

        return .success(project.toDTO())
    }

    @Sendable
    func update(req: Request) async throws -> APIResponse<Project> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid project ID")
        }

        guard let project = try await ProjectModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Project not found")
        }

        let request = try req.content.decode(UpdateProjectRequest.self)

        if let name = request.name {
            project.name = name
        }
        if let model = request.defaultModel {
            project.defaultModel = model
        }
        if let description = request.description {
            project.description = description
        }

        try await project.save(on: req.db)
        return .success(project.toDTO())
    }

    @Sendable
    func delete(req: Request) async throws -> APIResponse<Bool> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid project ID")
        }

        guard let project = try await ProjectModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Project not found")
        }

        try await project.delete(on: req.db)
        return .success(true)
    }

    @Sendable
    func getSessions(req: Request) async throws -> APIResponse<ListResponse<ChatSession>> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid project ID")
        }

        let sessions = try await SessionModel.query(on: req.db)
            .filter(\.$project.$id == id)
            .all()

        let project = try await ProjectModel.find(id, on: req.db)
        let dtos = sessions.map { $0.toDTO(projectName: project?.name) }
        return .success(ListResponse(items: dtos))
    }
}
```

**File:** `Sources/ILSBackend/Controllers/SessionsController.swift`

```swift
import Vapor
import Fluent
import ILSShared

struct SessionsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let sessions = routes.grouped("sessions")
        sessions.get(use: list)
        sessions.post(use: create)
        sessions.get("scan", use: scan)
        sessions.get(":id", use: get)
        sessions.delete(":id", use: delete)
        sessions.post(":id", "fork", use: fork)
    }

    @Sendable
    func list(req: Request) async throws -> APIResponse<ListResponse<ChatSession>> {
        var query = SessionModel.query(on: req.db)

        if let projectId = req.query[UUID.self, at: "projectId"] {
            query = query.filter(\.$project.$id == projectId)
        }

        let sessions = try await query.with(\.$project).all()
        let dtos = sessions.map { $0.toDTO(projectName: $0.project?.name) }
        return .success(ListResponse(items: dtos))
    }

    @Sendable
    func create(req: Request) async throws -> APIResponse<ChatSession> {
        let request = try req.content.decode(CreateSessionRequest.self)

        let session = SessionModel(
            name: request.name,
            projectId: request.projectId,
            model: request.model,
            permissionMode: request.permissionMode.rawValue
        )

        try await session.save(on: req.db)

        var projectName: String?
        if let projectId = request.projectId {
            projectName = try await ProjectModel.find(projectId, on: req.db)?.name
        }

        return .success(session.toDTO(projectName: projectName))
    }

    @Sendable
    func scan(req: Request) async throws -> APIResponse<ListResponse<ChatSession>> {
        // Scan ~/.claude/projects/ for external sessions
        let projectsPath = NSString(string: ClaudeConfigPaths.projectsDirectory).expandingTildeInPath
        let fileManager = FileManager.default

        var sessions: [ChatSession] = []

        if fileManager.fileExists(atPath: projectsPath) {
            let contents = try fileManager.contentsOfDirectory(atPath: projectsPath)

            for item in contents {
                let itemPath = (projectsPath as NSString).appendingPathComponent(item)
                var isDirectory: ObjCBool = false

                if fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory), isDirectory.boolValue {
                    // This is a project directory, look for session files
                    let sessionsDir = (itemPath as NSString).appendingPathComponent("sessions")
                    if fileManager.fileExists(atPath: sessionsDir) {
                        let sessionFiles = try fileManager.contentsOfDirectory(atPath: sessionsDir)
                        for sessionFile in sessionFiles where sessionFile.hasSuffix(".json") {
                            let sessionId = String(sessionFile.dropLast(5)) // Remove .json
                            sessions.append(ChatSession(
                                claudeSessionId: sessionId,
                                projectName: item,
                                model: "unknown",
                                permissionMode: .default,
                                status: .completed,
                                messageCount: 0,
                                source: .external
                            ))
                        }
                    }
                }
            }
        }

        return .success(ListResponse(items: sessions))
    }

    @Sendable
    func get(req: Request) async throws -> APIResponse<ChatSession> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }

        guard let session = try await SessionModel.query(on: req.db)
            .filter(\.$id == id)
            .with(\.$project)
            .first() else {
            throw Abort(.notFound, reason: "Session not found")
        }

        return .success(session.toDTO(projectName: session.project?.name))
    }

    @Sendable
    func delete(req: Request) async throws -> APIResponse<Bool> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }

        guard let session = try await SessionModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Session not found")
        }

        try await session.delete(on: req.db)
        return .success(true)
    }

    @Sendable
    func fork(req: Request) async throws -> APIResponse<ChatSession> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }

        guard let original = try await SessionModel.query(on: req.db)
            .filter(\.$id == id)
            .with(\.$project)
            .first() else {
            throw Abort(.notFound, reason: "Session not found")
        }

        let forked = SessionModel(
            name: "Fork of \(original.name ?? "Untitled")",
            projectId: original.$project.id,
            model: original.model,
            permissionMode: original.permissionMode
        )

        try await forked.save(on: req.db)
        return .success(forked.toDTO(projectName: original.project?.name))
    }
}
```

**File:** `Sources/ILSBackend/Controllers/ChatController.swift`

```swift
import Vapor
import ILSShared

struct ChatController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let chat = routes.grouped("chat")
        chat.post("stream", use: stream)
        chat.post("permission", ":requestId", use: permission)
        chat.post("cancel", ":sessionId", use: cancel)
    }

    @Sendable
    func stream(req: Request) async throws -> Response {
        let request = try req.content.decode(ChatRequest.self)

        let response = Response(status: .ok)
        response.headers.contentType = HTTPMediaType(type: "text", subType: "event-stream")
        response.headers.add(name: "Cache-Control", value: "no-cache")
        response.headers.add(name: "Connection", value: "keep-alive")

        // Get working directory from project
        var workingDirectory: String?
        if let projectId = request.projectId {
            if let project = try await ProjectModel.find(projectId, on: req.db) {
                workingDirectory = project.path
            }
        }

        let sessionId = UUID().uuidString
        let model = request.options?.model ?? "sonnet"
        let permissionMode = request.options?.permissionMode?.rawValue ?? "default"

        response.body = .init(asyncStream: { writer in
            do {
                // Send init message
                let initMessage = StreamingService.systemInit(
                    sessionId: sessionId,
                    slashCommands: ["/help", "/compact", "/clear"]
                )
                try await writer.write(.buffer(.init(string: StreamingService.formatMessage(initMessage))))

                // Execute Claude CLI
                let result = try await ClaudeExecutorService.shared.execute(
                    prompt: request.prompt,
                    workingDirectory: workingDirectory,
                    model: model,
                    permissionMode: permissionMode
                ) { line in
                    // Stream each line as SSE
                    if !line.isEmpty {
                        try? await writer.write(.buffer(.init(string: StreamingService.formatSSE(event: "data", data: line))))
                    }
                }

                // Send result message
                let resultMessage = StreamingService.result(
                    sessionId: result.sessionId ?? sessionId,
                    durationMs: 0,
                    costUSD: result.totalCostUSD,
                    inputTokens: 0,
                    outputTokens: 0
                )
                try await writer.write(.buffer(.init(string: StreamingService.formatMessage(resultMessage))))

            } catch {
                let errorSSE = StreamingService.formatSSE(event: "error", data: "{\"error\":\"\(error.localizedDescription)\"}")
                try? await writer.write(.buffer(.init(string: errorSSE)))
            }

            try await writer.write(.end)
        })

        return response
    }

    @Sendable
    func permission(req: Request) async throws -> APIResponse<Bool> {
        guard let _ = req.parameters.get("requestId") else {
            throw Abort(.badRequest, reason: "Invalid request ID")
        }

        // TODO: Handle permission responses
        return .success(true)
    }

    @Sendable
    func cancel(req: Request) async throws -> APIResponse<Bool> {
        guard let _ = req.parameters.get("sessionId") else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }

        // TODO: Cancel running session
        return .success(true)
    }
}
```

**File:** `Sources/ILSBackend/Controllers/SkillsController.swift`

```swift
import Vapor
import ILSShared

struct SkillsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let skills = routes.grouped("skills")
        skills.get(use: list)
        skills.post(use: create)
        skills.get(":name", use: get)
        skills.put(":name", use: update)
        skills.delete(":name", use: delete)
    }

    @Sendable
    func list(req: Request) async throws -> APIResponse<ListResponse<Skill>> {
        let skillsPath = NSString(string: ClaudeConfigPaths.skillsDirectory).expandingTildeInPath
        let fileManager = FileManager.default

        var skills: [Skill] = []

        if fileManager.fileExists(atPath: skillsPath) {
            let contents = try fileManager.contentsOfDirectory(atPath: skillsPath)

            for item in contents {
                let itemPath = (skillsPath as NSString).appendingPathComponent(item)
                let skillFile = (itemPath as NSString).appendingPathComponent("SKILL.md")

                if fileManager.fileExists(atPath: skillFile) {
                    let content = try String(contentsOfFile: skillFile, encoding: .utf8)

                    if let parsed = try? SkillParser.parse(content) {
                        skills.append(Skill(
                            name: parsed.name,
                            description: parsed.description,
                            isActive: true,
                            path: itemPath,
                            rawContent: content,
                            source: .local
                        ))
                    }
                }
            }
        }

        return .success(ListResponse(items: skills))
    }

    @Sendable
    func create(req: Request) async throws -> APIResponse<Skill> {
        let request = try req.content.decode(CreateSkillRequest.self)

        let skillsPath = NSString(string: ClaudeConfigPaths.skillsDirectory).expandingTildeInPath
        let skillPath = (skillsPath as NSString).appendingPathComponent(request.name)
        let skillFile = (skillPath as NSString).appendingPathComponent("SKILL.md")

        let fileManager = FileManager.default

        // Create skill directory
        try fileManager.createDirectory(atPath: skillPath, withIntermediateDirectories: true)

        // Generate SKILL.md content
        let content = SkillParser.generateContent(
            name: request.name,
            description: request.description,
            instructions: request.content
        )

        try content.write(toFile: skillFile, atomically: true, encoding: .utf8)

        let skill = Skill(
            name: request.name,
            description: request.description,
            isActive: true,
            path: skillPath,
            rawContent: content,
            source: .local
        )

        return .success(skill)
    }

    @Sendable
    func get(req: Request) async throws -> APIResponse<Skill> {
        guard let name = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Skill name required")
        }

        let skillsPath = NSString(string: ClaudeConfigPaths.skillsDirectory).expandingTildeInPath
        let skillPath = (skillsPath as NSString).appendingPathComponent(name)
        let skillFile = (skillPath as NSString).appendingPathComponent("SKILL.md")

        guard FileManager.default.fileExists(atPath: skillFile) else {
            throw Abort(.notFound, reason: "Skill not found")
        }

        let content = try String(contentsOfFile: skillFile, encoding: .utf8)
        let parsed = try SkillParser.parse(content)

        let skill = Skill(
            name: parsed.name,
            description: parsed.description,
            isActive: true,
            path: skillPath,
            rawContent: content,
            source: .local
        )

        return .success(skill)
    }

    @Sendable
    func update(req: Request) async throws -> APIResponse<Skill> {
        guard let name = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Skill name required")
        }

        let request = try req.content.decode(UpdateSkillRequest.self)

        let skillsPath = NSString(string: ClaudeConfigPaths.skillsDirectory).expandingTildeInPath
        let skillPath = (skillsPath as NSString).appendingPathComponent(name)
        let skillFile = (skillPath as NSString).appendingPathComponent("SKILL.md")

        guard FileManager.default.fileExists(atPath: skillFile) else {
            throw Abort(.notFound, reason: "Skill not found")
        }

        try request.content.write(toFile: skillFile, atomically: true, encoding: .utf8)

        let parsed = try SkillParser.parse(request.content)

        let skill = Skill(
            name: parsed.name,
            description: parsed.description,
            isActive: true,
            path: skillPath,
            rawContent: request.content,
            source: .local
        )

        return .success(skill)
    }

    @Sendable
    func delete(req: Request) async throws -> APIResponse<Bool> {
        guard let name = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Skill name required")
        }

        let skillsPath = NSString(string: ClaudeConfigPaths.skillsDirectory).expandingTildeInPath
        let skillPath = (skillsPath as NSString).appendingPathComponent(name)

        guard FileManager.default.fileExists(atPath: skillPath) else {
            throw Abort(.notFound, reason: "Skill not found")
        }

        try FileManager.default.removeItem(atPath: skillPath)
        return .success(true)
    }
}
```

**File:** `Sources/ILSBackend/Controllers/MCPController.swift`

```swift
import Vapor
import ILSShared

struct MCPController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let mcp = routes.grouped("mcp")
        mcp.get(use: list)
        mcp.post(use: create)
        mcp.put(":name", use: update)
        mcp.delete(":name", use: delete)
    }

    @Sendable
    func list(req: Request) async throws -> APIResponse<ListResponse<MCPServer>> {
        let scopeParam = req.query[String.self, at: "scope"]
        let filterScope = scopeParam.flatMap { MCPServer.ConfigScope(rawValue: $0) }

        var servers: [MCPServer] = []

        // Read user MCP config
        let userMCPPath = NSString(string: ClaudeConfigPaths.userMCP).expandingTildeInPath
        if FileManager.default.fileExists(atPath: userMCPPath) {
            let data = try Data(contentsOf: URL(fileURLWithPath: userMCPPath))
            if let config = try? JSONDecoder().decode(MCPConfiguration.self, from: data) {
                for (name, definition) in config.mcpServers {
                    servers.append(MCPServer(
                        name: name,
                        command: definition.command,
                        args: definition.args ?? [],
                        env: definition.env ?? [:],
                        scope: .user,
                        status: .unknown,
                        configPath: userMCPPath
                    ))
                }
            }
        }

        // Filter by scope if specified
        if let scope = filterScope {
            servers = servers.filter { $0.scope == scope }
        }

        return .success(ListResponse(items: servers))
    }

    @Sendable
    func create(req: Request) async throws -> APIResponse<MCPServer> {
        let request = try req.content.decode(CreateMCPServerRequest.self)

        let configPath: String
        switch request.scope {
        case .user:
            configPath = NSString(string: ClaudeConfigPaths.userMCP).expandingTildeInPath
        case .project:
            configPath = ClaudeConfigPaths.projectMCP
        default:
            configPath = NSString(string: ClaudeConfigPaths.userMCP).expandingTildeInPath
        }

        // Read existing config
        var config = MCPConfiguration()
        if FileManager.default.fileExists(atPath: configPath) {
            let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
            config = (try? JSONDecoder().decode(MCPConfiguration.self, from: data)) ?? MCPConfiguration()
        }

        // Add new server
        config.mcpServers[request.name] = MCPServerDefinition(
            command: request.command,
            args: request.args,
            env: request.env
        )

        // Write back
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: URL(fileURLWithPath: configPath))

        let server = MCPServer(
            name: request.name,
            command: request.command,
            args: request.args ?? [],
            env: request.env ?? [:],
            scope: request.scope,
            status: .unknown,
            configPath: configPath
        )

        return .success(server)
    }

    @Sendable
    func update(req: Request) async throws -> APIResponse<MCPServer> {
        guard let name = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Server name required")
        }

        let request = try req.content.decode(CreateMCPServerRequest.self)

        // For now, just return the updated server
        let server = MCPServer(
            name: name,
            command: request.command,
            args: request.args ?? [],
            env: request.env ?? [:],
            scope: request.scope,
            status: .unknown
        )

        return .success(server)
    }

    @Sendable
    func delete(req: Request) async throws -> APIResponse<Bool> {
        guard let name = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Server name required")
        }

        let configPath = NSString(string: ClaudeConfigPaths.userMCP).expandingTildeInPath

        if FileManager.default.fileExists(atPath: configPath) {
            let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
            var config = (try? JSONDecoder().decode(MCPConfiguration.self, from: data)) ?? MCPConfiguration()

            config.mcpServers.removeValue(forKey: name)

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let newData = try encoder.encode(config)
            try newData.write(to: URL(fileURLWithPath: configPath))
        }

        return .success(true)
    }
}
```

**File:** `Sources/ILSBackend/Controllers/PluginsController.swift`

```swift
import Vapor
import ILSShared

struct PluginsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let plugins = routes.grouped("plugins")
        plugins.get(use: list)
        plugins.get("marketplace", use: marketplace)
        plugins.post("install", use: install)
        plugins.post(":name", "enable", use: enable)
        plugins.post(":name", "disable", use: disable)
        plugins.delete(":name", use: uninstall)
    }

    @Sendable
    func list(req: Request) async throws -> APIResponse<ListResponse<Plugin>> {
        // Read installed plugins from cache
        let cachePath = NSString(string: ClaudeConfigPaths.pluginsCache).expandingTildeInPath
        var plugins: [Plugin] = []

        if FileManager.default.fileExists(atPath: cachePath) {
            let contents = try FileManager.default.contentsOfDirectory(atPath: cachePath)

            for item in contents {
                let pluginPath = (cachePath as NSString).appendingPathComponent(item)
                let manifestPath = (pluginPath as NSString).appendingPathComponent("plugin.json")

                if FileManager.default.fileExists(atPath: manifestPath) {
                    let data = try Data(contentsOf: URL(fileURLWithPath: manifestPath))
                    if let manifest = try? JSONDecoder().decode(PluginManifest.self, from: data) {
                        plugins.append(Plugin(
                            name: manifest.name,
                            description: manifest.description,
                            marketplace: "local",
                            isInstalled: true,
                            isEnabled: true,
                            version: manifest.version,
                            source: .official
                        ))
                    }
                }
            }
        }

        return .success(ListResponse(items: plugins))
    }

    @Sendable
    func marketplace(req: Request) async throws -> APIResponse<[Marketplace]> {
        // Return known marketplaces
        let marketplaces = [
            Marketplace(
                name: "claude-plugins-official",
                owner: MarketplaceOwner(name: "Anthropic", url: "https://anthropic.com"),
                plugins: [],
                source: "anthropics/claude-code"
            )
        ]

        return .success(marketplaces)
    }

    @Sendable
    func install(req: Request) async throws -> APIResponse<Plugin> {
        let request = try req.content.decode(InstallPluginRequest.self)

        let plugin = Plugin(
            name: request.pluginName,
            marketplace: request.marketplace,
            isInstalled: true,
            isEnabled: true,
            source: .official
        )

        return .success(plugin)
    }

    @Sendable
    func enable(req: Request) async throws -> APIResponse<Bool> {
        guard let _ = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Plugin name required")
        }

        return .success(true)
    }

    @Sendable
    func disable(req: Request) async throws -> APIResponse<Bool> {
        guard let _ = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Plugin name required")
        }

        return .success(true)
    }

    @Sendable
    func uninstall(req: Request) async throws -> APIResponse<Bool> {
        guard let _ = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Plugin name required")
        }

        return .success(true)
    }
}
```

**File:** `Sources/ILSBackend/Controllers/ConfigController.swift`

```swift
import Vapor
import ILSShared

struct ConfigController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let config = routes.grouped("config")
        config.get(use: get)
        config.put(use: update)
        config.post("validate", use: validate)
    }

    @Sendable
    func get(req: Request) async throws -> ConfigResponse {
        let scopeParam = req.query[String.self, at: "scope"] ?? "user"

        let path: String
        switch scopeParam {
        case "project":
            path = ClaudeConfigPaths.projectSettings
        case "local":
            path = ClaudeConfigPaths.localSettings
        default:
            path = NSString(string: ClaudeConfigPaths.userSettings).expandingTildeInPath
        }

        var config = ClaudeConfig()
        var isValid = true

        if FileManager.default.fileExists(atPath: path) {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            if let decoded = try? JSONDecoder().decode(ClaudeConfig.self, from: data) {
                config = decoded
            } else {
                isValid = false
            }
        }

        return ConfigResponse(
            scope: scopeParam,
            path: path,
            content: config,
            isValid: isValid
        )
    }

    @Sendable
    func update(req: Request) async throws -> APIResponse<Bool> {
        let request = try req.content.decode(UpdateConfigRequest.self)

        let path: String
        switch request.scope {
        case "project":
            path = ClaudeConfigPaths.projectSettings
        case "local":
            path = ClaudeConfigPaths.localSettings
        default:
            path = NSString(string: ClaudeConfigPaths.userSettings).expandingTildeInPath
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(request.content)

        // Create directory if needed
        let directory = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)

        try data.write(to: URL(fileURLWithPath: path))

        return .success(true)
    }

    @Sendable
    func validate(req: Request) async throws -> ConfigValidationResult {
        let request = try req.content.decode(ValidateConfigRequest.self)

        guard let data = request.content.data(using: .utf8) else {
            return ConfigValidationResult(isValid: false, errors: ["Invalid encoding"])
        }

        do {
            _ = try JSONDecoder().decode(ClaudeConfig.self, from: data)
            return ConfigValidationResult(isValid: true, errors: [])
        } catch {
            return ConfigValidationResult(isValid: false, errors: [error.localizedDescription])
        }
    }
}

struct ConfigResponse: Content {
    let scope: String
    let path: String
    let content: ClaudeConfig
    let isValid: Bool
}

struct ConfigValidationResult: Content {
    let isValid: Bool
    let errors: [String]
}
```

**File:** `Sources/ILSBackend/Controllers/StatsController.swift`

```swift
import Vapor
import Fluent
import ILSShared

struct StatsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let stats = routes.grouped("stats")
        stats.get(use: dashboard)
    }

    @Sendable
    func dashboard(req: Request) async throws -> APIResponse<DashboardStats> {
        // Count sessions
        let totalSessions = try await SessionModel.query(on: req.db).count()
        let activeSessions = try await SessionModel.query(on: req.db)
            .filter(\.$status == "active")
            .count()

        // Count projects
        let totalProjects = try await ProjectModel.query(on: req.db).count()

        // Count skills from filesystem
        let skillsPath = NSString(string: ClaudeConfigPaths.skillsDirectory).expandingTildeInPath
        var totalSkills = 0
        if FileManager.default.fileExists(atPath: skillsPath) {
            let contents = try FileManager.default.contentsOfDirectory(atPath: skillsPath)
            totalSkills = contents.filter { item in
                let skillFile = (skillsPath as NSString).appendingPathComponent(item)
                    .appending("/SKILL.md")
                return FileManager.default.fileExists(atPath: skillFile)
            }.count
        }

        // Count MCP servers
        var totalMCP = 0
        let mcpPath = NSString(string: ClaudeConfigPaths.userMCP).expandingTildeInPath
        if FileManager.default.fileExists(atPath: mcpPath) {
            let data = try Data(contentsOf: URL(fileURLWithPath: mcpPath))
            if let config = try? JSONDecoder().decode(MCPConfiguration.self, from: data) {
                totalMCP = config.mcpServers.count
            }
        }

        // Count plugins
        var totalPlugins = 0
        let pluginsPath = NSString(string: ClaudeConfigPaths.pluginsCache).expandingTildeInPath
        if FileManager.default.fileExists(atPath: pluginsPath) {
            let contents = try FileManager.default.contentsOfDirectory(atPath: pluginsPath)
            totalPlugins = contents.count
        }

        let stats = DashboardStats(
            sessions: ResourceStats(total: totalSessions, active: activeSessions),
            projects: ResourceStats(total: totalProjects, active: totalProjects),
            skills: ResourceStats(total: totalSkills, active: totalSkills),
            mcpServers: ResourceStats(total: totalMCP, active: totalMCP),
            plugins: ResourceStats(total: totalPlugins, active: totalPlugins)
        )

        return .success(stats)
    }
}
```

**Validation Criteria:**
- [ ] Run `swift build --target ILSBackend`
- [ ] Build must succeed with zero errors
- [ ] Evidence: Terminal output showing "Build complete!"

**Evidence Required:**

```
EVIDENCE_2A.5:
- Type: Terminal Output
- Command: `swift build --target ILSBackend 2>&1`
- Expected: "Build complete!" with no errors
- Actual: [PASTE OUTPUT]
- Timestamp: [YYYY-MM-DD HH:MM:SS]
- Status: PASS/FAIL
```

**BLOCKING:** Cannot proceed to Task 2A.6 until PASS

---

### Task 2A.6: Create Vapor Extensions for ILSShared Types

**Sub-Agent Assignment:** ALPHA

**File:** `Sources/ILSBackend/Extensions/VaporContent+Extensions.swift`

```swift
import Vapor
import ILSShared

// MARK: - Content Conformance for ILSShared Types

extension Project: Content {}
extension ChatSession: Content {}
extension Skill: Content {}
extension MCPServer: Content {}
extension Plugin: Content {}
extension Marketplace: Content {}
extension ClaudeConfig: Content {}

// MARK: - Request Types

extension CreateProjectRequest: Content {}
extension UpdateProjectRequest: Content {}
extension CreateSessionRequest: Content {}
extension ChatRequest: Content {}
extension ChatOptions: Content {}
extension CreateSkillRequest: Content {}
extension UpdateSkillRequest: Content {}
extension CreateMCPServerRequest: Content {}
extension InstallPluginRequest: Content {}
extension UpdateConfigRequest: Content {}
extension ValidateConfigRequest: Content {}

// MARK: - Response Types

extension APIResponse: Content where T: Content {}
extension ListResponse: Content where T: Content {}
extension DashboardStats: Content {}
extension ResourceStats: Content {}
extension APIError: Content {}

// MARK: - Nested Types

extension MarketplaceOwner: Content {}
extension MarketplacePlugin: Content {}
extension PluginSourceDefinition: Content {}
extension PermissionsConfig: Content {}
extension HooksConfig: Content {}
extension HookDefinition: Content {}
extension MarketplaceConfig: Content {}
extension MCPConfiguration: Content {}
extension MCPServerDefinition: Content {}

// MARK: - AsyncResponseEncodable for generic APIResponse

extension APIResponse: AsyncResponseEncodable where T: Content {
    public func encodeResponse(for request: Request) async throws -> Response {
        let response = Response()
        try response.content.encode(self)
        return response
    }
}
```

**Validation Criteria:**
- [ ] Run `swift build --target ILSBackend`
- [ ] Build succeeds

---

### Task 2A.7: Build and Test Backend with cURL

**Sub-Agent Assignment:** ALPHA

**Actions:**

```bash
# Build backend
swift build --target ILSBackend

# Run the server in background
swift run ILSBackend &
SERVER_PID=$!
sleep 5

# Test health endpoint
echo "=== Health Check ==="
curl -s http://localhost:8080/health

# Test stats endpoint
echo "=== Stats Endpoint ==="
curl -s http://localhost:8080/api/v1/stats | jq

# Test projects list
echo "=== Projects List ==="
curl -s http://localhost:8080/api/v1/projects | jq

# Test create project
echo "=== Create Project ==="
curl -s -X POST http://localhost:8080/api/v1/projects \
  -H "Content-Type: application/json" \
  -d '{"name":"test-project","path":"/tmp/test-project"}' | jq

# Test sessions list
echo "=== Sessions List ==="
curl -s http://localhost:8080/api/v1/sessions | jq

# Test skills list
echo "=== Skills List ==="
curl -s http://localhost:8080/api/v1/skills | jq

# Test MCP list
echo "=== MCP Servers ==="
curl -s http://localhost:8080/api/v1/mcp | jq

# Test plugins list
echo "=== Plugins ==="
curl -s http://localhost:8080/api/v1/plugins | jq

# Test config
echo "=== Config ==="
curl -s http://localhost:8080/api/v1/config | jq

# Cleanup
kill $SERVER_PID
```

**Validation Criteria:**
- [ ] `swift build --target ILSBackend` succeeds with zero errors
- [ ] Server starts and responds to health check with "OK"
- [ ] ALL 8 API endpoints return valid JSON
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
- Expected: JSON with sessions, projects, skills, mcpServers, plugins
- Actual: [PASTE FULL JSON]

PROJECTS ENDPOINT:
- Command: `curl -s http://localhost:8080/api/v1/projects`
- Expected: JSON with success and items array
- Actual: [PASTE FULL JSON]

SESSIONS ENDPOINT:
- Command: `curl -s http://localhost:8080/api/v1/sessions`
- Expected: JSON with success and items array
- Actual: [PASTE FULL JSON]

SKILLS ENDPOINT:
- Command: `curl -s http://localhost:8080/api/v1/skills`
- Expected: JSON with success and items array
- Actual: [PASTE FULL JSON]

MCP ENDPOINT:
- Command: `curl -s http://localhost:8080/api/v1/mcp`
- Expected: JSON with success and items array
- Actual: [PASTE FULL JSON]

PLUGINS ENDPOINT:
- Command: `curl -s http://localhost:8080/api/v1/plugins`
- Expected: JSON with success and items array
- Actual: [PASTE FULL JSON]

CONFIG ENDPOINT:
- Command: `curl -s http://localhost:8080/api/v1/config`
- Expected: JSON with scope, path, content, isValid
- Actual: [PASTE FULL JSON]

- Timestamp: [YYYY-MM-DD HH:MM:SS]
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
- Projects Endpoint: PASS/FAIL
- Sessions Endpoint: PASS/FAIL
- Skills Endpoint: PASS/FAIL
- MCP Endpoint: PASS/FAIL
- Plugins Endpoint: PASS/FAIL
- Config Endpoint: PASS/FAIL

OVERALL: PASS only if ALL = PASS
```

</phase_2a>

---

## PHASE 2B: Design System (SUB-AGENT BETA)

<phase_2b>

### Sub-Agent Prompt: BETA

```
<sub_agent_beta>
You are SUB-AGENT BETA responsible for building the SwiftUI design system.

CRITICAL CONSTRAINTS:
- You work ONLY on ILSApp/ILSApp/Theme/ files
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

Create the following color asset files in `ILSApp/ILSApp/Assets.xcassets/`:

**File:** `ILSApp/ILSApp/Assets.xcassets/AccentColor.colorset/Contents.json`

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

**Additional color assets needed:**
- `BackgroundPrimary` - #000000 (RGB: 0, 0, 0)
- `BackgroundSecondary` - #0D0D0D (RGB: 13, 13, 13)
- `BackgroundTertiary` - #1A1A1A (RGB: 26, 26, 26)
- `TextPrimary` - #FFFFFF (RGB: 255, 255, 255)
- `TextSecondary` - #A0A0A0 (RGB: 160, 160, 160)
- `BorderDefault` - #2A2A2A (RGB: 42, 42, 42)
- `Success` - #4CAF50 (RGB: 76, 175, 80)
- `Warning` - #FFA726 (RGB: 255, 167, 38)
- `Error` - #EF5350 (RGB: 239, 83, 80)

---

### Task 2B.2: Create ILSTheme.swift

**Sub-Agent Assignment:** BETA

**File:** `ILSApp/ILSApp/Theme/ILSTheme.swift`

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

        // Fallback colors
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

    // MARK: - Shadows

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
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ILSTheme.Typography.headline)
            .foregroundColor(.white)
            .padding(.horizontal, ILSTheme.Spacing.lg)
            .padding(.vertical, ILSTheme.Spacing.md)
            .background(
                configuration.isPressed
                    ? (isDestructive ? ILSTheme.Colors.error.opacity(0.8) : ILSTheme.Colors.accentTertiary)
                    : (isDestructive ? ILSTheme.Colors.error : ILSTheme.Colors.accentPrimary)
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
- [ ] Preview renders correctly

**Evidence Required:**

```
EVIDENCE_2B.2:
- Type: Xcode Screenshot
- Shows: Build succeeded indicator + Theme file open
- Filename: evidence_2b2_theme_compiled.png
- Timestamp: [YYYY-MM-DD HH:MM:SS]
- Status: PASS/FAIL
```

---

### GATE CHECK 2B: Design System Complete

```
GATE_CHECK_2B:
- ILSTheme.swift compiles: PASS/FAIL
- Color assets created: PASS/FAIL
- Preview renders correctly: PASS/FAIL

OVERALL: PASS only if ALL = PASS
```

</phase_2b>

---

## GATE CHECK 2: Sync Point

<gate_check_2>

**BOTH Sub-Agents must complete before proceeding:**

```
GATE_CHECK_2_SYNC:
- Gate Check 2A (Backend): PASS/FAIL
- Gate Check 2B (Design System): PASS/FAIL

PROCEED TO PHASE 3: Only if BOTH = PASS
```

**If either fails:**
1. Identify failing sub-agent
2. Review evidence
3. Fix issues
4. Re-run validation
5. DO NOT proceed until both pass

</gate_check_2>

---

## PHASE 3: iOS App - View by View

<phase_3>

### CRITICAL: Sequential Execution Only

Each view MUST:
1. Be coded completely
2. Compile without errors
3. Render in Simulator
4. Screenshot captured as evidence
5. ONLY THEN proceed to next view

---

### Task 3.1: Create ILSApp Entry Point and Tab Structure

**Sub-Agent Assignment:** MAIN AGENT

**File:** `Sources/ILSApp/ILSApp.swift`

```swift
import SwiftUI
import ILSShared

@main
struct ILSApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var currentConnection: ServerConnection?
    @Published var backendURL: URL = URL(string: "http://localhost:8080")!

    // Lazy-loaded API client
    lazy var apiClient: APIClient = APIClient(baseURL: backendURL)
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.isConnected {
                MainTabView()
            } else {
                ServerConnectionView()
            }
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: Tab = .dashboard

    enum Tab: String, CaseIterable {
        case dashboard = "Dashboard"
        case skills = "Skills"
        case mcp = "MCP"
        case plugins = "Plugins"
        case chat = "Chat"

        var icon: String {
            switch self {
            case .dashboard: return "house.fill"
            case .skills: return "doc.text.fill"
            case .mcp: return "server.rack"
            case .plugins: return "shippingbox.fill"
            case .chat: return "bubble.left.and.bubble.right.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label(Tab.dashboard.rawValue, systemImage: Tab.dashboard.icon)
                }
                .tag(Tab.dashboard)

            SkillsListView()
                .tabItem {
                    Label(Tab.skills.rawValue, systemImage: Tab.skills.icon)
                }
                .tag(Tab.skills)

            MCPServerListView()
                .tabItem {
                    Label(Tab.mcp.rawValue, systemImage: Tab.mcp.icon)
                }
                .tag(Tab.mcp)

            PluginMarketplaceView()
                .tabItem {
                    Label(Tab.plugins.rawValue, systemImage: Tab.plugins.icon)
                }
                .tag(Tab.plugins)

            ChatView()
                .tabItem {
                    Label(Tab.chat.rawValue, systemImage: Tab.chat.icon)
                }
                .tag(Tab.chat)
        }
        .tint(ILSTheme.Colors.accentPrimary)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
```

**Validation Criteria:**
- [ ] File compiles without errors
- [ ] App launches in Simulator
- [ ] Shows ServerConnectionView initially (not connected)
- [ ] Dark theme applied throughout

**Evidence Required:**

```
EVIDENCE_3.1:
- Type: iOS Simulator Screenshot + Build Log
- Command: `xcodebuild -scheme ILSApp -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build`
- Screenshot: App launch showing ServerConnectionView
- Must Verify:
  - [ ] Dark background (#000000)
  - [ ] No compilation errors
  - [ ] ServerConnectionView visible
- Filename: evidence_3.1_app_launch.png
- Status: PASS/FAIL
```

**BLOCKING:** Cannot proceed to 3.2 until PASS

---

### Task 3.2: Create ServerConnectionView

**Sub-Agent Assignment:** MAIN AGENT

**File:** `Sources/ILSApp/Views/ServerConnection/ServerConnectionView.swift`

```swift
import SwiftUI
import ILSShared

struct ServerConnectionView: View {
    @EnvironmentObject var appState: AppState

    @State private var host: String = ""
    @State private var port: String = "22"
    @State private var username: String = ""
    @State private var authMethod: AuthMethod = .sshKey
    @State private var password: String = ""
    @State private var selectedKeyPath: String = ""
    @State private var isConnecting: Bool = false
    @State private var errorMessage: String?
    @State private var recentConnections: [ServerConnection] = []

    enum AuthMethod: String, CaseIterable {
        case password = "Password"
        case sshKey = "SSH Key"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ILSTheme.Spacing.lg) {
                    // Header Card
                    VStack(spacing: ILSTheme.Spacing.md) {
                        Image(systemName: "desktopcomputer")
                            .font(.system(size: 48))
                            .foregroundColor(ILSTheme.Colors.accentPrimary)

                        Text("Connect to Server")
                            .font(ILSTheme.Typography.title1)
                            .foregroundColor(ILSTheme.Colors.textPrimary)

                        Text("Connect to a remote host running Claude Code")
                            .font(ILSTheme.Typography.subheadline)
                            .foregroundColor(ILSTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(ILSTheme.Spacing.lg)
                    .frame(maxWidth: .infinity)
                    .ilsCard()

                    // Connection Form
                    VStack(alignment: .leading, spacing: ILSTheme.Spacing.md) {
                        Text("Connection Details")
                            .font(ILSTheme.Typography.headline)
                            .foregroundColor(ILSTheme.Colors.textPrimary)

                        ILSTextField(
                            label: "Host",
                            placeholder: "192.168.1.100 or hostname",
                            text: $host,
                            icon: "network"
                        )

                        ILSTextField(
                            label: "Port",
                            placeholder: "22",
                            text: $port,
                            icon: "number",
                            keyboardType: .numberPad
                        )

                        ILSTextField(
                            label: "Username",
                            placeholder: "admin",
                            text: $username,
                            icon: "person.fill"
                        )

                        // Auth Method Picker
                        VStack(alignment: .leading, spacing: ILSTheme.Spacing.sm) {
                            Text("Authentication")
                                .font(ILSTheme.Typography.caption)
                                .foregroundColor(ILSTheme.Colors.textSecondary)

                            Picker("Auth Method", selection: $authMethod) {
                                ForEach(AuthMethod.allCases, id: \.self) { method in
                                    Text(method.rawValue).tag(method)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        if authMethod == .password {
                            ILSTextField(
                                label: "Password",
                                placeholder: "Enter password",
                                text: $password,
                                icon: "lock.fill",
                                isSecure: true
                            )
                        } else {
                            // SSH Key Selection
                            VStack(alignment: .leading, spacing: ILSTheme.Spacing.sm) {
                                Text("SSH Key")
                                    .font(ILSTheme.Typography.caption)
                                    .foregroundColor(ILSTheme.Colors.textSecondary)

                                Button(action: selectKeyFile) {
                                    HStack {
                                        Image(systemName: "key.fill")
                                            .foregroundColor(ILSTheme.Colors.accentPrimary)

                                        Text(selectedKeyPath.isEmpty ? "Select Key File..." : selectedKeyPath)
                                            .foregroundColor(selectedKeyPath.isEmpty ? ILSTheme.Colors.textTertiary : ILSTheme.Colors.textPrimary)

                                        Spacer()

                                        Image(systemName: "folder.fill")
                                            .foregroundColor(ILSTheme.Colors.textSecondary)
                                    }
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

                        // Error Message
                        if let error = errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(ILSTheme.Colors.error)
                                Text(error)
                                    .font(ILSTheme.Typography.caption)
                                    .foregroundColor(ILSTheme.Colors.error)
                            }
                            .padding(ILSTheme.Spacing.md)
                            .background(ILSTheme.Colors.error.opacity(0.1))
                            .cornerRadius(ILSTheme.CornerRadius.small)
                        }

                        // Connect Button
                        Button(action: connect) {
                            HStack {
                                if isConnecting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                }
                                Text(isConnecting ? "Connecting..." : "Connect")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ILSPrimaryButtonStyle())
                        .disabled(isConnecting || !isFormValid)
                    }
                    .padding(ILSTheme.Spacing.md)
                    .ilsCard()

                    // Recent Connections
                    if !recentConnections.isEmpty {
                        VStack(alignment: .leading, spacing: ILSTheme.Spacing.sm) {
                            Text("Recent Connections")
                                .font(ILSTheme.Typography.headline)
                                .foregroundColor(ILSTheme.Colors.textPrimary)

                            ForEach(recentConnections) { connection in
                                RecentConnectionRow(
                                    connection: connection,
                                    onTap: { selectConnection(connection) }
                                )
                            }
                        }
                        .padding(ILSTheme.Spacing.md)
                        .ilsCard()
                    }

                    // Local Development Option
                    VStack(alignment: .leading, spacing: ILSTheme.Spacing.sm) {
                        Text("Local Development")
                            .font(ILSTheme.Typography.headline)
                            .foregroundColor(ILSTheme.Colors.textPrimary)

                        Button(action: connectLocal) {
                            HStack {
                                Image(systemName: "laptopcomputer")
                                    .foregroundColor(ILSTheme.Colors.accentPrimary)

                                VStack(alignment: .leading) {
                                    Text("Connect Locally")
                                        .font(ILSTheme.Typography.body)
                                        .foregroundColor(ILSTheme.Colors.textPrimary)

                                    Text("Use localhost:8080 for development")
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
                    .padding(ILSTheme.Spacing.md)
                    .ilsCard()

                    Spacer(minLength: ILSTheme.Spacing.xl)
                }
                .padding(.horizontal, ILSTheme.Spacing.lg)
                .padding(.top, ILSTheme.Spacing.md)
            }
            .background(ILSTheme.Colors.backgroundPrimary)
            .navigationTitle("ILS")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var isFormValid: Bool {
        !host.isEmpty && !port.isEmpty && !username.isEmpty &&
        (authMethod == .password ? !password.isEmpty : !selectedKeyPath.isEmpty)
    }

    private func selectKeyFile() {
        // In real implementation, would use document picker
        selectedKeyPath = "~/.ssh/id_rsa"
    }

    private func connect() {
        isConnecting = true
        errorMessage = nil

        // Simulate connection delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isConnecting = false

            let connection = ServerConnection(
                id: UUID(),
                name: host,
                host: host,
                port: Int(port) ?? 22,
                username: username,
                authMethod: authMethod == .password ? .password : .sshKey(path: selectedKeyPath),
                lastConnected: Date(),
                status: .connected
            )

            appState.currentConnection = connection
            appState.isConnected = true
        }
    }

    private func connectLocal() {
        appState.backendURL = URL(string: "http://localhost:8080")!
        appState.isConnected = true
    }

    private func selectConnection(_ connection: ServerConnection) {
        host = connection.host
        port = String(connection.port)
        username = connection.username

        if case .sshKey(let path) = connection.authMethod {
            authMethod = .sshKey
            selectedKeyPath = path
        } else {
            authMethod = .password
        }
    }
}

// MARK: - Supporting Views

struct ILSTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: ILSTheme.Spacing.sm) {
            Text(label)
                .font(ILSTheme.Typography.caption)
                .foregroundColor(ILSTheme.Colors.textSecondary)

            HStack {
                if let iconName = icon {
                    Image(systemName: iconName)
                        .foregroundColor(ILSTheme.Colors.textSecondary)
                        .frame(width: 20)
                }

                if isSecure {
                    SecureField(placeholder, text: $text)
                        .font(ILSTheme.Typography.body)
                        .foregroundColor(ILSTheme.Colors.textPrimary)
                } else {
                    TextField(placeholder, text: $text)
                        .font(ILSTheme.Typography.body)
                        .foregroundColor(ILSTheme.Colors.textPrimary)
                        .keyboardType(keyboardType)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
            }
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
    let connection: ServerConnection
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Circle()
                    .fill(connection.status == .connected ? ILSTheme.Colors.success : ILSTheme.Colors.textTertiary)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(connection.name)
                        .font(ILSTheme.Typography.body)
                        .foregroundColor(ILSTheme.Colors.textPrimary)

                    Text("\(connection.username)@\(connection.host)")
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
}

#Preview {
    ServerConnectionView()
        .environmentObject(AppState())
}
```

**Validation Criteria:**
- [ ] File compiles without errors
- [ ] View renders in Simulator
- [ ] All form fields visible and functional
- [ ] Dark theme with orange accent applied

**Evidence Required:**

```
EVIDENCE_3.2:
- Type: iOS Simulator Screenshot
- Screenshot: ServerConnectionView fully visible
- Must Verify:
  - [ ] "Connect to Server" header with desktop icon
  - [ ] Host, Port, Username fields visible
  - [ ] Auth method picker (Password/SSH Key)
  - [ ] Orange "Connect" button
  - [ ] "Local Development" section at bottom
  - [ ] Dark background throughout
- Filename: evidence_3.2_server_connection.png
- Status: PASS/FAIL
```

**BLOCKING:** Cannot proceed to 3.3 until PASS

---

### Task 3.3: Create DashboardView

**Sub-Agent Assignment:** MAIN AGENT

**File:** `Sources/ILSApp/Views/Dashboard/DashboardView.swift`

```swift
import SwiftUI
import ILSShared

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var stats: DashboardStats?
    @State private var recentActivity: [ActivityItem] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ILSTheme.Spacing.lg) {
                    // Stats Cards
                    HStack(spacing: ILSTheme.Spacing.md) {
                        StatCard(
                            value: stats?.skillCount ?? 0,
                            label: "Skills",
                            icon: "doc.text.fill",
                            color: ILSTheme.Colors.accentPrimary
                        )

                        StatCard(
                            value: stats?.mcpServerCount ?? 0,
                            label: "MCPs",
                            icon: "server.rack",
                            color: ILSTheme.Colors.success
                        )

                        StatCard(
                            value: stats?.pluginCount ?? 0,
                            label: "Plugins",
                            icon: "shippingbox.fill",
                            color: ILSTheme.Colors.warning
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
                            subtitle: "Search GitHub for skills"
                        ) {
                            // Navigate to skills search
                        }

                        QuickActionRow(
                            icon: "shippingbox",
                            title: "Browse Plugin Marketplace",
                            subtitle: "Install official plugins"
                        ) {
                            // Navigate to marketplace
                        }

                        QuickActionRow(
                            icon: "server.rack",
                            title: "Configure MCP Servers",
                            subtitle: "Manage server connections"
                        ) {
                            // Navigate to MCP
                        }

                        QuickActionRow(
                            icon: "gearshape.fill",
                            title: "Edit Claude Settings",
                            subtitle: "Modify configuration files"
                        ) {
                            // Navigate to settings
                        }
                    }
                    .padding(ILSTheme.Spacing.md)
                    .ilsCard()

                    // Recent Activity
                    VStack(alignment: .leading, spacing: ILSTheme.Spacing.sm) {
                        Text("Recent Activity")
                            .font(ILSTheme.Typography.headline)
                            .foregroundColor(ILSTheme.Colors.textPrimary)

                        if recentActivity.isEmpty {
                            Text("No recent activity")
                                .font(ILSTheme.Typography.body)
                                .foregroundColor(ILSTheme.Colors.textSecondary)
                                .padding(ILSTheme.Spacing.lg)
                                .frame(maxWidth: .infinity)
                        } else {
                            ForEach(recentActivity) { activity in
                                ActivityRow(activity: activity)
                            }
                        }
                    }
                    .padding(ILSTheme.Spacing.md)
                    .ilsCard()

                    // Sessions Section
                    VStack(alignment: .leading, spacing: ILSTheme.Spacing.sm) {
                        HStack {
                            Text("Active Sessions")
                                .font(ILSTheme.Typography.headline)
                                .foregroundColor(ILSTheme.Colors.textPrimary)

                            Spacer()

                            NavigationLink(destination: SessionListView()) {
                                Text("See All")
                                    .font(ILSTheme.Typography.caption)
                                    .foregroundColor(ILSTheme.Colors.accentPrimary)
                            }
                        }

                        Text("0 active chat sessions")
                            .font(ILSTheme.Typography.body)
                            .foregroundColor(ILSTheme.Colors.textSecondary)
                            .padding(ILSTheme.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ILSTheme.Colors.backgroundTertiary)
                            .cornerRadius(ILSTheme.CornerRadius.small)
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

                        Text(appState.currentConnection?.name ?? "localhost")
                            .font(ILSTheme.Typography.caption)
                            .foregroundColor(ILSTheme.Colors.textSecondary)
                    }
                }
            }
            .refreshable {
                await loadData()
            }
        }
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            stats = try await appState.apiClient.getStats()

            // Mock recent activity for now
            recentActivity = [
                ActivityItem(
                    id: UUID(),
                    icon: "checkmark.circle.fill",
                    iconColor: ILSTheme.Colors.success,
                    title: "Installed code-review",
                    timestamp: Date().addingTimeInterval(-7200)
                ),
                ActivityItem(
                    id: UUID(),
                    icon: "arrow.triangle.2.circlepath",
                    iconColor: ILSTheme.Colors.accentPrimary,
                    title: "Updated github MCP",
                    timestamp: Date().addingTimeInterval(-86400)
                )
            ]
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: ILSTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)

            Text("\(value)")
                .font(ILSTheme.Typography.title1)
                .foregroundColor(ILSTheme.Colors.textPrimary)

            Text(label)
                .font(ILSTheme.Typography.caption)
                .foregroundColor(ILSTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(ILSTheme.Spacing.md)
        .ilsCard()
    }
}

struct QuickActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(ILSTheme.Colors.accentPrimary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(ILSTheme.Typography.body)
                        .foregroundColor(ILSTheme.Colors.textPrimary)

                    Text(subtitle)
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
}

struct ActivityItem: Identifiable {
    let id: UUID
    let icon: String
    let iconColor: Color
    let title: String
    let timestamp: Date

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

struct ActivityRow: View {
    let activity: ActivityItem

    var body: some View {
        HStack {
            Image(systemName: activity.icon)
                .foregroundColor(activity.iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(ILSTheme.Typography.body)
                    .foregroundColor(ILSTheme.Colors.textPrimary)

                Text(activity.timeAgo)
                    .font(ILSTheme.Typography.caption)
                    .foregroundColor(ILSTheme.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(ILSTheme.Spacing.md)
        .background(ILSTheme.Colors.backgroundTertiary)
        .cornerRadius(ILSTheme.CornerRadius.small)
    }
}

// Placeholder for SessionListView
struct SessionListView: View {
    var body: some View {
        Text("Sessions")
            .navigationTitle("Sessions")
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppState())
}
```

**Validation Criteria:**
- [ ] File compiles without errors
- [ ] Dashboard renders with stat cards
- [ ] Quick actions section visible
- [ ] Recent activity section visible

**Evidence Required:**

```
EVIDENCE_3.3:
- Type: iOS Simulator Screenshot
- Screenshot: DashboardView fully rendered
- Must Verify:
  - [ ] 3 stat cards (Skills, MCPs, Plugins)
  - [ ] Quick Actions section with 4 rows
  - [ ] Recent Activity section
  - [ ] Active Sessions section
  - [ ] Connection status in toolbar
  - [ ] Dark theme with orange accents
- Filename: evidence_3.3_dashboard.png
- Status: PASS/FAIL
```

**BLOCKING:** Cannot proceed to 3.4 until PASS

---

### Task 3.4: Create SkillsListView and SkillDetailView

**Sub-Agent Assignment:** MAIN AGENT

**File:** `Sources/ILSApp/Views/Skills/SkillsListView.swift`

```swift
import SwiftUI
import ILSShared

struct SkillsListView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText: String = ""
    @State private var skills: [Skill] = []
    @State private var discoveredSkills: [GitHubSearchResult] = []
    @State private var isLoading: Bool = true
    @State private var isSearching: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ILSTheme.Spacing.lg) {
                    // Installed Skills Section
                    VStack(alignment: .leading, spacing: ILSTheme.Spacing.sm) {
                        Text("Installed Skills")
                            .font(ILSTheme.Typography.headline)
                            .foregroundColor(ILSTheme.Colors.textPrimary)

                        if skills.isEmpty && !isLoading {
                            Text("No skills installed")
                                .font(ILSTheme.Typography.body)
                                .foregroundColor(ILSTheme.Colors.textSecondary)
                                .padding(ILSTheme.Spacing.lg)
                                .frame(maxWidth: .infinity)
                        } else {
                            ForEach(skills) { skill in
                                NavigationLink(destination: SkillDetailView(skill: skill)) {
                                    SkillRow(skill: skill)
                                }
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
                            .onSubmit {
                                Task { await searchSkills() }
                            }

                        if isSearching {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .padding(ILSTheme.Spacing.md)
                    .background(ILSTheme.Colors.backgroundTertiary)
                    .cornerRadius(ILSTheme.CornerRadius.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: ILSTheme.CornerRadius.small)
                            .stroke(ILSTheme.Colors.borderDefault, lineWidth: 1)
                    )

                    // Discovered Skills Section
                    if !discoveredSkills.isEmpty {
                        VStack(alignment: .leading, spacing: ILSTheme.Spacing.sm) {
                            Text("Discovered from GitHub")
                                .font(ILSTheme.Typography.headline)
                                .foregroundColor(ILSTheme.Colors.textPrimary)

                            ForEach(discoveredSkills, id: \.repository) { result in
                                DiscoveredSkillRow(result: result) {
                                    Task { await installSkill(result) }
                                }
                            }
                        }
                        .padding(ILSTheme.Spacing.md)
                        .ilsCard()
                    }

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
                    Button(action: { /* Add skill */ }) {
                        Image(systemName: "plus")
                            .foregroundColor(ILSTheme.Colors.accentPrimary)
                    }
                }
            }
            .refreshable {
                await loadSkills()
            }
        }
        .task {
            await loadSkills()
        }
    }

    private func loadSkills() async {
        isLoading = true
        do {
            skills = try await appState.apiClient.getSkills()
        } catch {
            // Handle error
        }
        isLoading = false
    }

    private func searchSkills() async {
        guard !searchText.isEmpty else { return }
        isSearching = true
        do {
            discoveredSkills = try await appState.apiClient.searchSkills(query: searchText)
        } catch {
            // Handle error
        }
        isSearching = false
    }

    private func installSkill(_ result: GitHubSearchResult) async {
        do {
            try await appState.apiClient.installSkill(from: result.htmlUrl)
            await loadSkills()
        } catch {
            // Handle error
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

            Image(systemName: "chevron.right")
                .foregroundColor(ILSTheme.Colors.textTertiary)
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
        .environmentObject(AppState())
}
```

**File:** `Sources/ILSApp/Views/Skills/SkillDetailView.swift`

```swift
import SwiftUI
import ILSShared

struct SkillDetailView: View {
    let skill: Skill
    @EnvironmentObject var appState: AppState
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @Environment(\.dismiss) private var dismiss

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

                // Path Info
                VStack(alignment: .leading, spacing: ILSTheme.Spacing.sm) {
                    Text("Location")
                        .font(ILSTheme.Typography.headline)
                        .foregroundColor(ILSTheme.Colors.textPrimary)

                    Text(skill.path)
                        .font(ILSTheme.Typography.code)
                        .foregroundColor(ILSTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(ILSTheme.Spacing.md)
                .ilsCard()

                // Actions
                VStack(spacing: ILSTheme.Spacing.md) {
                    Button(action: { showDeleteConfirmation = true }) {
                        HStack {
                            if isDeleting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "trash")
                            }
                            Text(isDeleting ? "Uninstalling..." : "Uninstall")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .foregroundColor(.white)
                    .padding(ILSTheme.Spacing.md)
                    .background(ILSTheme.Colors.error)
                    .cornerRadius(ILSTheme.CornerRadius.small)
                    .disabled(isDeleting)

                    Button(action: { /* Edit skill */ }) {
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
            Button("Uninstall", role: .destructive) {
                Task { await uninstallSkill() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to uninstall \(skill.name)?")
        }
    }

    private func uninstallSkill() async {
        isDeleting = true
        do {
            try await appState.apiClient.deleteSkill(id: skill.id)
            dismiss()
        } catch {
            // Handle error
        }
        isDeleting = false
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
        .environmentObject(AppState())
    }
}
```

**Validation Criteria:**
- [ ] Both files compile without errors
- [ ] SkillsListView shows installed skills and search
- [ ] SkillDetailView shows skill info and actions
- [ ] Navigation between views works

**Evidence Required:**

```
EVIDENCE_3.4:
- Type: iOS Simulator Screenshots (2)

Screenshot 1 - Skills List:
- Shows: SkillsListView
- Must Verify:
  - [ ] "Installed Skills" section
  - [ ] Search field visible
  - [ ] Status badges on skills
  - [ ] Plus button in toolbar
- Filename: evidence_3.4a_skills_list.png

Screenshot 2 - Skill Detail:
- Shows: SkillDetailView (navigate to a skill)
- Must Verify:
  - [ ] Skill icon and name header
  - [ ] Description section
  - [ ] SKILL.md preview section
  - [ ] Location section
  - [ ] Red Uninstall button
  - [ ] Edit SKILL.md button
- Filename: evidence_3.4b_skill_detail.png

- Status: PASS/FAIL (both required)
```

**BLOCKING:** Cannot proceed to 3.5 until PASS

---

### Task 3.5: Create MCPServerListView

**Sub-Agent Assignment:** MAIN AGENT

**File:** `Sources/ILSApp/Views/MCP/MCPServerListView.swift`

```swift
import SwiftUI
import ILSShared

struct MCPServerListView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedScope: MCPServer.ConfigScope = .user
    @State private var servers: [MCPServer] = []
    @State private var isLoading: Bool = true
    @State private var showAddSheet: Bool = false

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
                                MCPServerRow(
                                    server: server,
                                    onDisable: { toggleServer(server) },
                                    onEdit: { editServer(server) },
                                    onDelete: { deleteServer(server) },
                                    onRetry: { retryServer(server) }
                                )
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
                AddMCPServerView(selectedScope: selectedScope) { newServer in
                    servers.append(newServer)
                }
            }
            .refreshable {
                await loadServers()
            }
        }
        .task {
            await loadServers()
        }
    }

    private func loadServers() async {
        isLoading = true
        do {
            servers = try await appState.apiClient.getMCPServers()
        } catch {
            // Handle error
        }
        isLoading = false
    }

    private func toggleServer(_ server: MCPServer) {
        // Toggle server enabled state
    }

    private func editServer(_ server: MCPServer) {
        // Open edit sheet
    }

    private func deleteServer(_ server: MCPServer) {
        Task {
            do {
                try await appState.apiClient.deleteMCPServer(id: server.id)
                servers.removeAll { $0.id == server.id }
            } catch {
                // Handle error
            }
        }
    }

    private func retryServer(_ server: MCPServer) {
        // Retry connection
    }
}

struct MCPServerRow: View {
    let server: MCPServer
    let onDisable: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onRetry: () -> Void

    var statusColor: Color {
        switch server.status {
        case .healthy: return ILSTheme.Colors.success
        case .error: return ILSTheme.Colors.error
        case .disabled: return ILSTheme.Colors.textTertiary
        case .unknown: return ILSTheme.Colors.warning
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ILSTheme.Spacing.sm) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)

                Text(server.name)
                    .font(ILSTheme.Typography.body)
                    .foregroundColor(ILSTheme.Colors.textPrimary)

                if server.status == .error {
                    Text("(error)")
                        .font(ILSTheme.Typography.caption)
                        .foregroundColor(ILSTheme.Colors.error)
                }

                Spacer()
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

            // Action Buttons
            HStack(spacing: ILSTheme.Spacing.sm) {
                if server.status == .error {
                    Button("Retry", action: onRetry)
                        .font(ILSTheme.Typography.caption)
                        .foregroundColor(ILSTheme.Colors.accentPrimary)
                } else {
                    Button(server.status == .disabled ? "Enable" : "Disable", action: onDisable)
                        .font(ILSTheme.Typography.caption)
                        .foregroundColor(ILSTheme.Colors.textSecondary)
                }

                Button("Edit", action: onEdit)
                    .font(ILSTheme.Typography.caption)
                    .foregroundColor(ILSTheme.Colors.textSecondary)

                Button("Delete", action: onDelete)
                    .font(ILSTheme.Typography.caption)
                    .foregroundColor(ILSTheme.Colors.error)
            }
        }
        .padding(ILSTheme.Spacing.md)
        .background(ILSTheme.Colors.backgroundTertiary)
        .cornerRadius(ILSTheme.CornerRadius.small)
    }
}

struct AddMCPServerView: View {
    let selectedScope: MCPServer.ConfigScope
    let onAdd: (MCPServer) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var command: String = "npx"
    @State private var args: String = ""
    @State private var envPairs: [(key: String, value: String)] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Server Details") {
                    TextField("Name", text: $name)
                    TextField("Command", text: $command)
                    TextField("Arguments (space-separated)", text: $args)
                }

                Section("Environment Variables") {
                    ForEach(envPairs.indices, id: \.self) { index in
                        HStack {
                            TextField("Key", text: Binding(
                                get: { envPairs[index].key },
                                set: { envPairs[index].key = $0 }
                            ))
                            TextField("Value", text: Binding(
                                get: { envPairs[index].value },
                                set: { envPairs[index].value = $0 }
                            ))
                            Button(action: { envPairs.remove(at: index) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(ILSTheme.Colors.error)
                            }
                        }
                    }

                    Button(action: { envPairs.append((key: "", value: "")) }) {
                        Label("Add Variable", systemImage: "plus")
                    }
                }

                Section {
                    Text("Scope: \(selectedScope.rawValue)")
                        .foregroundColor(ILSTheme.Colors.textSecondary)
                }
            }
            .navigationTitle("Add MCP Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let env = Dictionary(uniqueKeysWithValues: envPairs.filter { !$0.key.isEmpty })
                        let server = MCPServer(
                            name: name,
                            command: command,
                            args: args.split(separator: " ").map(String.init),
                            env: env,
                            scope: selectedScope,
                            status: .unknown
                        )
                        onAdd(server)
                        dismiss()
                    }
                    .disabled(name.isEmpty || command.isEmpty)
                }
            }
        }
    }
}

#Preview {
    MCPServerListView()
        .environmentObject(AppState())
}
```

**Validation Criteria:**
- [ ] File compiles without errors
- [ ] Scope picker works (User/Project/Local)
- [ ] Server rows show status indicators
- [ ] Add server sheet opens correctly

**Evidence Required:**

```
EVIDENCE_3.5:
- Type: iOS Simulator Screenshot
- Screenshot: MCPServerListView with servers
- Must Verify:
  - [ ] Scope picker (User/Project/Local)
  - [ ] Active Servers section
  - [ ] Server rows with status (green/red dots)
  - [ ] Command and env info visible
  - [ ] Action buttons (Disable/Edit/Delete)
  - [ ] "Add Custom MCP Server" button
- Filename: evidence_3.5_mcp_servers.png
- Status: PASS/FAIL
```

**BLOCKING:** Cannot proceed to 3.6 until PASS

---

### Task 3.6: Create PluginMarketplaceView

**Sub-Agent Assignment:** MAIN AGENT

**File:** `Sources/ILSApp/Views/Plugins/PluginMarketplaceView.swift`

```swift
import SwiftUI
import ILSShared

struct PluginMarketplaceView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText: String = ""
    @State private var selectedCategory: String = "All"
    @State private var plugins: [Plugin] = []
    @State private var installedPlugins: Set<String> = []
    @State private var isLoading: Bool = true
    @State private var installingPlugin: String?

    let categories = ["All", "Productivity", "DevOps", "Testing", "Documentation"]

    var filteredPlugins: [Plugin] {
        plugins.filter { plugin in
            let matchesSearch = searchText.isEmpty ||
                plugin.name.localizedCaseInsensitiveContains(searchText) ||
                plugin.description.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategory == "All" ||
                plugin.category == selectedCategory
            return matchesSearch && matchesCategory
        }
    }

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
                                CategoryChip(
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
                        Text("Official Marketplace")
                            .font(ILSTheme.Typography.headline)
                            .foregroundColor(ILSTheme.Colors.textPrimary)

                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(ILSTheme.Spacing.lg)
                        } else if filteredPlugins.isEmpty {
                            Text("No plugins found")
                                .font(ILSTheme.Typography.body)
                                .foregroundColor(ILSTheme.Colors.textSecondary)
                                .padding(ILSTheme.Spacing.lg)
                                .frame(maxWidth: .infinity)
                        } else {
                            ForEach(filteredPlugins) { plugin in
                                PluginRow(
                                    plugin: plugin,
                                    isInstalled: installedPlugins.contains(plugin.id.uuidString),
                                    isInstalling: installingPlugin == plugin.id.uuidString
                                ) {
                                    Task { await installPlugin(plugin) }
                                }
                            }
                        }
                    }
                    .padding(ILSTheme.Spacing.md)
                    .ilsCard()

                    // Add Custom Marketplace
                    VStack(alignment: .leading, spacing: ILSTheme.Spacing.sm) {
                        Text("Custom Marketplaces")
                            .font(ILSTheme.Typography.headline)
                            .foregroundColor(ILSTheme.Colors.textPrimary)

                        Button(action: { /* Add marketplace */ }) {
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
            .navigationTitle("Plugins")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadPlugins()
            }
        }
        .task {
            await loadPlugins()
        }
    }

    private func loadPlugins() async {
        isLoading = true
        do {
            plugins = try await appState.apiClient.getPlugins()
            // Load installed plugins
            let installed = try await appState.apiClient.getInstalledPlugins()
            installedPlugins = Set(installed.map { $0.id.uuidString })
        } catch {
            // Handle error
        }
        isLoading = false
    }

    private func installPlugin(_ plugin: Plugin) async {
        installingPlugin = plugin.id.uuidString
        do {
            try await appState.apiClient.installPlugin(id: plugin.id)
            installedPlugins.insert(plugin.id.uuidString)
        } catch {
            // Handle error
        }
        installingPlugin = nil
    }
}

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(ILSTheme.Typography.caption)
                .foregroundColor(isSelected ? .white : ILSTheme.Colors.textSecondary)
                .padding(.horizontal, ILSTheme.Spacing.md)
                .padding(.vertical, ILSTheme.Spacing.sm)
                .background(isSelected ? ILSTheme.Colors.accentPrimary : ILSTheme.Colors.backgroundTertiary)
                .cornerRadius(ILSTheme.CornerRadius.small)
        }
    }
}

struct PluginRow: View {
    let plugin: Plugin
    let isInstalled: Bool
    let isInstalling: Bool
    let onInstall: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 32))
                .foregroundColor(ILSTheme.Colors.accentPrimary)
                .frame(width: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(plugin.name)
                    .font(ILSTheme.Typography.body)
                    .foregroundColor(ILSTheme.Colors.textPrimary)

                Text(plugin.description)
                    .font(ILSTheme.Typography.caption)
                    .foregroundColor(ILSTheme.Colors.textSecondary)
                    .lineLimit(2)

                HStack(spacing: ILSTheme.Spacing.sm) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(ILSTheme.Colors.warning)
                        Text(formatStars(plugin.stars))
                            .font(ILSTheme.Typography.caption)
                            .foregroundColor(ILSTheme.Colors.textSecondary)
                    }

                    if plugin.isOfficial {
                        Text("Official")
                            .font(ILSTheme.Typography.caption)
                            .foregroundColor(ILSTheme.Colors.success)
                    }
                }
            }

            Spacer()

            if isInstalled {
                Text("Installed")
                    .font(ILSTheme.Typography.caption)
                    .foregroundColor(ILSTheme.Colors.textTertiary)
                    .padding(.horizontal, ILSTheme.Spacing.md)
                    .padding(.vertical, ILSTheme.Spacing.sm)
                    .background(ILSTheme.Colors.backgroundTertiary)
                    .cornerRadius(ILSTheme.CornerRadius.small)
            } else {
                Button(action: onInstall) {
                    if isInstalling {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.7)
                    } else {
                        Text("Install")
                    }
                }
                .font(ILSTheme.Typography.caption)
                .foregroundColor(.white)
                .padding(.horizontal, ILSTheme.Spacing.md)
                .padding(.vertical, ILSTheme.Spacing.sm)
                .background(ILSTheme.Colors.accentPrimary)
                .cornerRadius(ILSTheme.CornerRadius.small)
                .disabled(isInstalling)
            }
        }
        .padding(ILSTheme.Spacing.md)
        .background(ILSTheme.Colors.backgroundTertiary)
        .cornerRadius(ILSTheme.CornerRadius.small)
    }

    private func formatStars(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000)
        }
        return "\(count)"
    }
}

#Preview {
    PluginMarketplaceView()
        .environmentObject(AppState())
}
```

**Validation Criteria:**
- [ ] File compiles without errors
- [ ] Search field works
- [ ] Category chips selectable
- [ ] Plugin rows with Install/Installed state

**Evidence Required:**

```
EVIDENCE_3.6:
- Type: iOS Simulator Screenshot
- Screenshot: PluginMarketplaceView
- Must Verify:
  - [ ] Search field at top
  - [ ] Category chips (All, Productivity, etc.)
  - [ ] Plugin rows with icons
  - [ ] Star counts and "Official" badge
  - [ ] Orange "Install" buttons
  - [ ] "Installed" state for installed plugins
  - [ ] "Add from GitHub repo" button
- Filename: evidence_3.6_plugins.png
- Status: PASS/FAIL
```

**BLOCKING:** Cannot proceed to 3.7 until PASS

---

### Task 3.7: Create APIClient

**Sub-Agent Assignment:** MAIN AGENT

**File:** `Sources/ILSApp/Services/APIClient.swift`

```swift
import Foundation
import ILSShared

actor APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Stats

    func getStats() async throws -> DashboardStats {
        let url = baseURL.appendingPathComponent("api/v1/stats")
        return try await get(url: url)
    }

    // MARK: - Skills

    func getSkills() async throws -> [Skill] {
        let url = baseURL.appendingPathComponent("api/v1/skills")
        let response: APIResponse<[Skill]> = try await get(url: url)
        return response.data ?? []
    }

    func getSkill(id: UUID) async throws -> Skill {
        let url = baseURL.appendingPathComponent("api/v1/skills/\(id.uuidString)")
        let response: APIResponse<Skill> = try await get(url: url)
        guard let skill = response.data else {
            throw APIError.notFound
        }
        return skill
    }

    func searchSkills(query: String) async throws -> [GitHubSearchResult] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/v1/skills/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        let response: APIResponse<[GitHubSearchResult]> = try await get(url: components.url!)
        return response.data ?? []
    }

    func installSkill(from url: String) async throws {
        let endpoint = baseURL.appendingPathComponent("api/v1/skills/install")
        let body = ["url": url]
        let _: APIResponse<Skill> = try await post(url: endpoint, body: body)
    }

    func deleteSkill(id: UUID) async throws {
        let url = baseURL.appendingPathComponent("api/v1/skills/\(id.uuidString)")
        try await delete(url: url)
    }

    // MARK: - MCP Servers

    func getMCPServers(scope: MCPServer.ConfigScope? = nil) async throws -> [MCPServer] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/v1/mcp"), resolvingAgainstBaseURL: false)!
        if let scope = scope {
            components.queryItems = [URLQueryItem(name: "scope", value: scope.rawValue)]
        }
        let response: APIResponse<[MCPServer]> = try await get(url: components.url!)
        return response.data ?? []
    }

    func createMCPServer(_ server: MCPServer) async throws -> MCPServer {
        let url = baseURL.appendingPathComponent("api/v1/mcp")
        let response: APIResponse<MCPServer> = try await post(url: url, body: server)
        guard let created = response.data else {
            throw APIError.invalidResponse
        }
        return created
    }

    func updateMCPServer(_ server: MCPServer) async throws -> MCPServer {
        let url = baseURL.appendingPathComponent("api/v1/mcp/\(server.id.uuidString)")
        let response: APIResponse<MCPServer> = try await put(url: url, body: server)
        guard let updated = response.data else {
            throw APIError.invalidResponse
        }
        return updated
    }

    func deleteMCPServer(id: UUID) async throws {
        let url = baseURL.appendingPathComponent("api/v1/mcp/\(id.uuidString)")
        try await delete(url: url)
    }

    // MARK: - Plugins

    func getPlugins() async throws -> [Plugin] {
        let url = baseURL.appendingPathComponent("api/v1/plugins/marketplace")
        let response: APIResponse<[Plugin]> = try await get(url: url)
        return response.data ?? []
    }

    func getInstalledPlugins() async throws -> [Plugin] {
        let url = baseURL.appendingPathComponent("api/v1/plugins/installed")
        let response: APIResponse<[Plugin]> = try await get(url: url)
        return response.data ?? []
    }

    func installPlugin(id: UUID) async throws {
        let url = baseURL.appendingPathComponent("api/v1/plugins/install")
        let body = ["id": id.uuidString]
        let _: APIResponse<Plugin> = try await post(url: url, body: body)
    }

    func uninstallPlugin(id: UUID) async throws {
        let url = baseURL.appendingPathComponent("api/v1/plugins/\(id.uuidString)")
        try await delete(url: url)
    }

    // MARK: - Config

    func getConfig() async throws -> ClaudeConfig {
        let url = baseURL.appendingPathComponent("api/v1/config")
        let response: APIResponse<ClaudeConfig> = try await get(url: url)
        guard let config = response.data else {
            throw APIError.notFound
        }
        return config
    }

    func updateConfig(_ config: ClaudeConfig) async throws -> ClaudeConfig {
        let url = baseURL.appendingPathComponent("api/v1/config")
        let response: APIResponse<ClaudeConfig> = try await put(url: url, body: config)
        guard let updated = response.data else {
            throw APIError.invalidResponse
        }
        return updated
    }

    // MARK: - Sessions

    func getSessions() async throws -> [Session] {
        let url = baseURL.appendingPathComponent("api/v1/sessions")
        let response: APIResponse<[Session]> = try await get(url: url)
        return response.data ?? []
    }

    func createSession(projectPath: String) async throws -> Session {
        let url = baseURL.appendingPathComponent("api/v1/sessions")
        let body = ["projectPath": projectPath]
        let response: APIResponse<Session> = try await post(url: url, body: body)
        guard let session = response.data else {
            throw APIError.invalidResponse
        }
        return session
    }

    func getSession(id: UUID) async throws -> Session {
        let url = baseURL.appendingPathComponent("api/v1/sessions/\(id.uuidString)")
        let response: APIResponse<Session> = try await get(url: url)
        guard let session = response.data else {
            throw APIError.notFound
        }
        return session
    }

    // MARK: - Chat (SSE Streaming)

    func sendMessage(sessionId: UUID, content: String) -> AsyncThrowingStream<StreamMessage, Error> {
        let url = baseURL.appendingPathComponent("api/v1/sessions/\(sessionId.uuidString)/chat")

        return AsyncThrowingStream { continuation in
            Task {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                let body = ["content": content]
                request.httpBody = try? encoder.encode(body)

                do {
                    let (bytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        throw APIError.invalidResponse
                    }

                    var buffer = ""

                    for try await byte in bytes {
                        let char = Character(UnicodeScalar(byte))
                        buffer.append(char)

                        // SSE messages are separated by double newlines
                        while let range = buffer.range(of: "\n\n") {
                            let message = String(buffer[..<range.lowerBound])
                            buffer = String(buffer[range.upperBound...])

                            if let streamMessage = parseSSEMessage(message) {
                                continuation.yield(streamMessage)

                                if case .done = streamMessage.type {
                                    continuation.finish()
                                    return
                                }
                            }
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func parseSSEMessage(_ message: String) -> StreamMessage? {
        var event: String?
        var data: String?

        for line in message.split(separator: "\n") {
            if line.hasPrefix("event:") {
                event = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                data = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            }
        }

        guard let eventType = event, let jsonData = data?.data(using: .utf8) else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            switch eventType {
            case "text":
                let textData = try decoder.decode(StreamMessage.TextData.self, from: jsonData)
                return StreamMessage(type: .text, text: textData)
            case "thinking":
                let thinkingData = try decoder.decode(StreamMessage.ThinkingData.self, from: jsonData)
                return StreamMessage(type: .thinking, thinking: thinkingData)
            case "tool_use":
                let toolData = try decoder.decode(StreamMessage.ToolUseData.self, from: jsonData)
                return StreamMessage(type: .toolUse, toolUse: toolData)
            case "tool_result":
                let resultData = try decoder.decode(StreamMessage.ToolResultData.self, from: jsonData)
                return StreamMessage(type: .toolResult, toolResult: resultData)
            case "error":
                let errorData = try decoder.decode(StreamMessage.ErrorData.self, from: jsonData)
                return StreamMessage(type: .error, error: errorData)
            case "done":
                return StreamMessage(type: .done)
            default:
                return nil
            }
        } catch {
            return nil
        }
    }

    // MARK: - Generic Request Methods

    private func get<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try decoder.decode(T.self, from: data)
    }

    private func post<T: Decodable, B: Encodable>(url: URL, body: B) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try decoder.decode(T.self, from: data)
    }

    private func put<T: Decodable, B: Encodable>(url: URL, body: B) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try decoder.decode(T.self, from: data)
    }

    private func delete(url: URL) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        case 500...599:
            throw APIError.serverError(httpResponse.statusCode)
        default:
            throw APIError.unknown(httpResponse.statusCode)
        }
    }
}

enum APIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case notFound
    case serverError(Int)
    case unknown(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized"
        case .notFound:
            return "Resource not found"
        case .serverError(let code):
            return "Server error (\(code))"
        case .unknown(let code):
            return "Unknown error (\(code))"
        }
    }
}
```

**Validation Criteria:**
- [ ] File compiles without errors
- [ ] All API methods properly typed
- [ ] SSE streaming handler implemented
- [ ] Error handling complete

**Evidence Required:**

```
EVIDENCE_3.7:
- Type: Build Log
- Command: `swift build --target ILSApp`
- Must Verify:
  - [ ] APIClient.swift compiles
  - [ ] All async methods resolve
  - [ ] No type errors
- Status: PASS/FAIL
```

**BLOCKING:** Cannot proceed to Phase 4 until PASS

---

</phase_3>

<gate_check_3>

## GATE CHECK 3: iOS Views Phase

**OVERALL STATUS: PENDING**

| Task | Evidence | Status |
|------|----------|--------|
| 3.1 ILSApp Entry | Screenshot | PENDING |
| 3.2 ServerConnectionView | Screenshot | PENDING |
| 3.3 DashboardView | Screenshot | PENDING |
| 3.4 Skills Views | 2 Screenshots | PENDING |
| 3.5 MCP View | Screenshot | PENDING |
| 3.6 Plugins View | Screenshot | PENDING |
| 3.7 APIClient | Build Log | PENDING |

```
GATE_CHECK_3:
- All Views Compile: PENDING
- All Screenshots Captured: PENDING
- Navigation Works: PENDING
- Dark Theme Applied: PENDING
- Orange Accent Visible: PENDING

PROCEED TO PHASE 4: Only if ALL = PASS
```

</gate_check_3>

---

## PHASE 4: Chat/Session Integration

<phase_4>

### CRITICAL: User's Specific Validation Requirements

The user explicitly requested these validation gates:

1. **GATE_CHAT_1**: Chat/session screen - typing and using slash commands displays expected results
2. **GATE_SESSION_1**: Session management - creating new session with new project shows all existing system data
3. **GATE_MULTI_1**: Session interaction - multiple back-and-forth exchanges work correctly

These are **BLOCKING** requirements for project completion.

---

### Task 4.1: Create ChatView with SSE Streaming

**Sub-Agent Assignment:** MAIN AGENT

**File:** `Sources/ILSApp/Views/Chat/ChatView.swift`

```swift
import SwiftUI
import ILSShared

struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ChatViewModel()
    @State private var showSessionPicker = false
    @State private var showNewSessionSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Session Header
                if let session = viewModel.currentSession {
                    SessionHeaderView(
                        session: session,
                        onTap: { showSessionPicker = true }
                    )
                } else {
                    NoSessionView(onCreate: { showNewSessionSheet = true })
                }

                // Messages List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: ILSTheme.Spacing.md) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }

                            // Streaming indicator
                            if viewModel.isStreaming {
                                StreamingIndicator()
                                    .id("streaming")
                            }
                        }
                        .padding(.horizontal, ILSTheme.Spacing.md)
                        .padding(.vertical, ILSTheme.Spacing.lg)
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        withAnimation {
                            proxy.scrollTo(viewModel.messages.last?.id ?? "streaming", anchor: .bottom)
                        }
                    }
                }

                // Input Bar
                ChatInputBar(
                    text: $viewModel.inputText,
                    isEnabled: viewModel.currentSession != nil && !viewModel.isStreaming,
                    onSend: { viewModel.sendMessage() },
                    onSlashCommand: { command in
                        viewModel.handleSlashCommand(command)
                    }
                )
            }
            .background(ILSTheme.Colors.backgroundPrimary)
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showNewSessionSheet = true }) {
                        Image(systemName: "plus.message")
                            .foregroundColor(ILSTheme.Colors.accentPrimary)
                    }
                }
            }
            .sheet(isPresented: $showSessionPicker) {
                SessionPickerView(
                    sessions: viewModel.sessions,
                    currentSession: viewModel.currentSession,
                    onSelect: { session in
                        viewModel.selectSession(session)
                        showSessionPicker = false
                    }
                )
            }
            .sheet(isPresented: $showNewSessionSheet) {
                NewSessionView { projectPath in
                    Task {
                        await viewModel.createSession(projectPath: projectPath)
                        showNewSessionSheet = false
                    }
                }
            }
        }
        .task {
            await viewModel.initialize(apiClient: appState.apiClient)
        }
    }
}

// MARK: - Chat View Model

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isStreaming: Bool = false
    @Published var currentSession: Session?
    @Published var sessions: [Session] = []
    @Published var error: String?

    private var apiClient: APIClient?
    private var streamTask: Task<Void, Never>?

    func initialize(apiClient: APIClient) async {
        self.apiClient = apiClient
        await loadSessions()
    }

    func loadSessions() async {
        do {
            sessions = try await apiClient?.getSessions() ?? []
            if currentSession == nil, let first = sessions.first {
                await selectSession(first)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func selectSession(_ session: Session) async {
        currentSession = session
        messages = []

        // Load session history
        do {
            let fullSession = try await apiClient?.getSession(id: session.id)
            if let history = fullSession?.messages {
                messages = history
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func createSession(projectPath: String) async {
        do {
            let session = try await apiClient?.createSession(projectPath: projectPath)
            if let session = session {
                sessions.insert(session, at: 0)
                await selectSession(session)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func sendMessage() {
        guard let sessionId = currentSession?.id,
              !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let content = inputText
        inputText = ""

        // Add user message immediately
        let userMessage = ChatMessage(
            id: UUID(),
            role: .user,
            content: content,
            timestamp: Date()
        )
        messages.append(userMessage)

        // Start streaming
        isStreaming = true

        streamTask = Task {
            do {
                guard let stream = apiClient?.sendMessage(sessionId: sessionId, content: content) else {
                    return
                }

                var assistantContent = ""
                var currentThinking = ""
                var currentToolUse: ChatMessage.ToolUse?

                for try await event in stream {
                    switch event.type {
                    case .text:
                        if let text = event.text?.content {
                            assistantContent += text
                            updateOrAddAssistantMessage(content: assistantContent)
                        }

                    case .thinking:
                        if let thinking = event.thinking?.content {
                            currentThinking += thinking
                            updateThinkingIndicator(content: currentThinking)
                        }

                    case .toolUse:
                        if let tool = event.toolUse {
                            currentToolUse = ChatMessage.ToolUse(
                                name: tool.name,
                                input: tool.input,
                                status: .running
                            )
                            addToolUseMessage(currentToolUse!)
                        }

                    case .toolResult:
                        if let result = event.toolResult {
                            updateToolResult(toolId: result.toolUseId, output: result.output, isError: result.isError)
                        }

                    case .error:
                        if let errorMsg = event.error?.message {
                            self.error = errorMsg
                        }

                    case .done:
                        break
                    }
                }
            } catch {
                self.error = error.localizedDescription
            }

            isStreaming = false
        }
    }

    func handleSlashCommand(_ command: String) {
        // Handle slash commands like /help, /skills, etc.
        let message = "/\(command)"
        inputText = message
        sendMessage()
    }

    func cancelStream() {
        streamTask?.cancel()
        isStreaming = false
    }

    private func updateOrAddAssistantMessage(content: String) {
        if let lastIndex = messages.lastIndex(where: { $0.role == .assistant && $0.toolUse == nil }) {
            messages[lastIndex].content = content
        } else {
            let message = ChatMessage(
                id: UUID(),
                role: .assistant,
                content: content,
                timestamp: Date()
            )
            messages.append(message)
        }
    }

    private func updateThinkingIndicator(content: String) {
        // Update thinking indicator in UI
    }

    private func addToolUseMessage(_ toolUse: ChatMessage.ToolUse) {
        let message = ChatMessage(
            id: UUID(),
            role: .assistant,
            content: "",
            timestamp: Date(),
            toolUse: toolUse
        )
        messages.append(message)
    }

    private func updateToolResult(toolId: String, output: String, isError: Bool) {
        if let index = messages.lastIndex(where: { $0.toolUse != nil }) {
            messages[index].toolUse?.output = output
            messages[index].toolUse?.status = isError ? .error : .completed
        }
    }
}

// MARK: - Chat Message Model

struct ChatMessage: Identifiable {
    let id: UUID
    let role: Role
    var content: String
    let timestamp: Date
    var toolUse: ToolUse?

    enum Role {
        case user
        case assistant
        case system
    }

    struct ToolUse {
        let name: String
        let input: String
        var output: String?
        var status: Status

        enum Status {
            case running
            case completed
            case error
        }
    }
}

// MARK: - Supporting Views

struct SessionHeaderView: View {
    let session: Session
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(ILSTheme.Colors.accentPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.project?.name ?? "Unknown Project")
                        .font(ILSTheme.Typography.body)
                        .foregroundColor(ILSTheme.Colors.textPrimary)

                    Text(session.project?.path ?? "")
                        .font(ILSTheme.Typography.caption)
                        .foregroundColor(ILSTheme.Colors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .foregroundColor(ILSTheme.Colors.textTertiary)
            }
            .padding(ILSTheme.Spacing.md)
            .background(ILSTheme.Colors.backgroundSecondary)
        }
    }
}

struct NoSessionView: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: ILSTheme.Spacing.md) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(ILSTheme.Colors.textTertiary)

            Text("No Active Session")
                .font(ILSTheme.Typography.headline)
                .foregroundColor(ILSTheme.Colors.textPrimary)

            Text("Create a new session to start chatting with Claude")
                .font(ILSTheme.Typography.body)
                .foregroundColor(ILSTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button("New Session", action: onCreate)
                .buttonStyle(ILSPrimaryButtonStyle())
        }
        .padding(ILSTheme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: ILSTheme.Spacing.sm) {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: ILSTheme.Spacing.sm) {
                // Tool use indicator
                if let toolUse = message.toolUse {
                    ToolUseView(toolUse: toolUse)
                }

                // Message content
                if !message.content.isEmpty {
                    Text(message.content)
                        .font(ILSTheme.Typography.body)
                        .foregroundColor(message.role == .user ? .white : ILSTheme.Colors.textPrimary)
                        .padding(ILSTheme.Spacing.md)
                        .background(
                            message.role == .user ?
                            ILSTheme.Colors.accentPrimary :
                            ILSTheme.Colors.backgroundSecondary
                        )
                        .cornerRadius(ILSTheme.CornerRadius.medium)
                }

                // Timestamp
                Text(message.timestamp, style: .time)
                    .font(ILSTheme.Typography.caption)
                    .foregroundColor(ILSTheme.Colors.textTertiary)
            }

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
    }
}

struct ToolUseView: View {
    let toolUse: ChatMessage.ToolUse

    var statusColor: Color {
        switch toolUse.status {
        case .running: return ILSTheme.Colors.warning
        case .completed: return ILSTheme.Colors.success
        case .error: return ILSTheme.Colors.error
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ILSTheme.Spacing.sm) {
            HStack {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundColor(statusColor)

                Text(toolUse.name)
                    .font(ILSTheme.Typography.body)
                    .foregroundColor(ILSTheme.Colors.textPrimary)

                if toolUse.status == .running {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            // Input
            Text(toolUse.input)
                .font(ILSTheme.Typography.code)
                .foregroundColor(ILSTheme.Colors.textSecondary)
                .lineLimit(3)

            // Output
            if let output = toolUse.output {
                Divider()
                    .background(ILSTheme.Colors.borderDefault)

                Text(output)
                    .font(ILSTheme.Typography.code)
                    .foregroundColor(toolUse.status == .error ? ILSTheme.Colors.error : ILSTheme.Colors.textSecondary)
                    .lineLimit(5)
            }
        }
        .padding(ILSTheme.Spacing.md)
        .background(ILSTheme.Colors.backgroundTertiary)
        .cornerRadius(ILSTheme.CornerRadius.small)
        .overlay(
            RoundedRectangle(cornerRadius: ILSTheme.CornerRadius.small)
                .stroke(statusColor.opacity(0.5), lineWidth: 1)
        )
    }
}

struct StreamingIndicator: View {
    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack {
            Text("Claude is thinking" + String(repeating: ".", count: dotCount))
                .font(ILSTheme.Typography.body)
                .foregroundColor(ILSTheme.Colors.textSecondary)

            Spacer()
        }
        .padding(ILSTheme.Spacing.md)
        .background(ILSTheme.Colors.backgroundSecondary)
        .cornerRadius(ILSTheme.CornerRadius.medium)
        .onReceive(timer) { _ in
            dotCount = (dotCount + 1) % 4
        }
    }
}

struct ChatInputBar: View {
    @Binding var text: String
    let isEnabled: Bool
    let onSend: () -> Void
    let onSlashCommand: (String) -> Void

    @State private var showSlashCommands = false
    @FocusState private var isFocused: Bool

    let slashCommands = ["help", "skills", "mcp", "config", "clear"]

    var body: some View {
        VStack(spacing: 0) {
            // Slash command suggestions
            if showSlashCommands && text.hasPrefix("/") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ILSTheme.Spacing.sm) {
                        ForEach(filteredCommands, id: \.self) { command in
                            Button(action: {
                                text = "/\(command) "
                                showSlashCommands = false
                            }) {
                                Text("/\(command)")
                                    .font(ILSTheme.Typography.code)
                                    .foregroundColor(ILSTheme.Colors.accentPrimary)
                                    .padding(.horizontal, ILSTheme.Spacing.md)
                                    .padding(.vertical, ILSTheme.Spacing.sm)
                                    .background(ILSTheme.Colors.backgroundTertiary)
                                    .cornerRadius(ILSTheme.CornerRadius.small)
                            }
                        }
                    }
                    .padding(.horizontal, ILSTheme.Spacing.md)
                    .padding(.vertical, ILSTheme.Spacing.sm)
                }
                .background(ILSTheme.Colors.backgroundSecondary)
            }

            Divider()
                .background(ILSTheme.Colors.borderDefault)

            // Input row
            HStack(spacing: ILSTheme.Spacing.sm) {
                TextField("Message Claude...", text: $text)
                    .font(ILSTheme.Typography.body)
                    .foregroundColor(ILSTheme.Colors.textPrimary)
                    .focused($isFocused)
                    .disabled(!isEnabled)
                    .onChange(of: text) { _, newValue in
                        showSlashCommands = newValue.hasPrefix("/") && !newValue.contains(" ")
                    }
                    .onSubmit {
                        if isEnabled && !text.isEmpty {
                            onSend()
                        }
                    }

                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(
                            isEnabled && !text.isEmpty ?
                            ILSTheme.Colors.accentPrimary :
                            ILSTheme.Colors.textTertiary
                        )
                }
                .disabled(!isEnabled || text.isEmpty)
            }
            .padding(.horizontal, ILSTheme.Spacing.md)
            .padding(.vertical, ILSTheme.Spacing.sm)
            .background(ILSTheme.Colors.backgroundSecondary)
        }
    }

    var filteredCommands: [String] {
        let query = String(text.dropFirst()).lowercased()
        if query.isEmpty {
            return slashCommands
        }
        return slashCommands.filter { $0.hasPrefix(query) }
    }
}

struct SessionPickerView: View {
    let sessions: [Session]
    let currentSession: Session?
    let onSelect: (Session) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(sessions) { session in
                Button(action: { onSelect(session) }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(session.project?.name ?? "Unknown")
                                .font(ILSTheme.Typography.body)
                                .foregroundColor(ILSTheme.Colors.textPrimary)

                            Text(session.project?.path ?? "")
                                .font(ILSTheme.Typography.caption)
                                .foregroundColor(ILSTheme.Colors.textSecondary)
                        }

                        Spacer()

                        if session.id == currentSession?.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(ILSTheme.Colors.accentPrimary)
                        }
                    }
                }
            }
            .navigationTitle("Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct NewSessionView: View {
    let onCreate: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var projectPath: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Project Path") {
                    TextField("~/projects/my-project", text: $projectPath)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }

                Section {
                    Text("Enter the path to the project directory you want to work with.")
                        .font(ILSTheme.Typography.caption)
                        .foregroundColor(ILSTheme.Colors.textSecondary)
                }
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(projectPath)
                    }
                    .disabled(projectPath.isEmpty)
                }
            }
        }
    }
}

#Preview {
    ChatView()
        .environmentObject(AppState())
}
```

**Validation Criteria:**
- [ ] File compiles without errors
- [ ] Chat view renders with input bar
- [ ] Session selection works
- [ ] Message bubbles display correctly

**Evidence Required:**

```
EVIDENCE_4.1:
- Type: iOS Simulator Screenshot
- Screenshot: ChatView with messages
- Must Verify:
  - [ ] Session header visible
  - [ ] Message input bar at bottom
  - [ ] User/assistant message bubbles styled differently
  - [ ] Send button (orange)
- Filename: evidence_4.1_chat_view.png
- Status: PASS/FAIL
```

**BLOCKING:** Cannot proceed to 4.2 until PASS

---

### Task 4.2: Validation Gate - Slash Commands

**GATE_CHAT_1: Slash Command Validation**

This is a **USER-SPECIFIED CRITICAL GATE**.

**Requirement:** Typing and using slash commands displays expected results.

**Test Procedure:**
1. Launch app and navigate to Chat tab
2. Create or select a session
3. Type "/" in the input field
4. Verify slash command suggestions appear
5. Select "/help" command
6. Verify message is sent to backend
7. Verify response is received and displayed

**Evidence Required:**

```
EVIDENCE_4.2_GATE_CHAT_1:
- Type: iOS Simulator Screenshot Series (3 screenshots)

Screenshot 1 - Slash Trigger:
- Shows: Chat input with "/" typed
- Must Verify:
  - [ ] Slash command suggestions visible
  - [ ] Commands: /help, /skills, /mcp, /config, /clear
- Filename: evidence_4.2a_slash_trigger.png

Screenshot 2 - Command Selected:
- Shows: "/help" command in input
- Must Verify:
  - [ ] Full command visible in input
  - [ ] Send button enabled (orange)
- Filename: evidence_4.2b_command_selected.png

Screenshot 3 - Response Received:
- Shows: Chat with /help response
- Must Verify:
  - [ ] User message bubble with "/help"
  - [ ] Assistant response bubble with help text
  - [ ] Correct styling (dark theme, orange accents)
- Filename: evidence_4.2c_help_response.png

Backend Log Verification:
- Command: `curl -X POST http://localhost:8080/api/v1/sessions/{id}/chat -H "Content-Type: application/json" -d '{"content":"/help"}'`
- Expected: SSE stream with help content
- Actual: [PASTE OUTPUT]

- Status: PASS/FAIL (ALL 3 screenshots + backend log required)
```

**BLOCKING:** This is a user-specified critical gate. Cannot proceed until PASS.

---

### Task 4.3: Validation Gate - Session Management

**GATE_SESSION_1: New Session with System Data**

This is a **USER-SPECIFIED CRITICAL GATE**.

**Requirement:** Creating a new session with a new project shows all existing system data.

**Test Procedure:**
1. Ensure backend has data (skills, MCP servers, plugins installed)
2. Navigate to Chat tab
3. Tap "New Session" button
4. Enter project path: `~/test-project`
5. Create session
6. Verify session is created and selected
7. Send message asking about available skills
8. Verify response includes actual system data (not mocked)

**Evidence Required:**

```
EVIDENCE_4.3_GATE_SESSION_1:
- Type: iOS Simulator Screenshot Series (3 screenshots) + API Verification

Screenshot 1 - New Session Sheet:
- Shows: New Session creation form
- Must Verify:
  - [ ] Project path input field
  - [ ] Create button enabled when path entered
- Filename: evidence_4.3a_new_session.png

Screenshot 2 - Session Created:
- Shows: Chat view with new session
- Must Verify:
  - [ ] Session header shows project name
  - [ ] Empty chat (new session)
  - [ ] Input enabled
- Filename: evidence_4.3b_session_created.png

Screenshot 3 - System Data Response:
- Shows: Response to "What skills are available?"
- Must Verify:
  - [ ] Response lists actual installed skills
  - [ ] Data matches what's shown in Skills tab
- Filename: evidence_4.3c_system_data.png

API Verification:
- Command: `curl http://localhost:8080/api/v1/sessions | jq`
- Expected: New session with project path visible
- Actual: [PASTE OUTPUT]

Cross-Reference:
- Command: `curl http://localhost:8080/api/v1/skills | jq`
- Match: Skills in API response must match chat response
- Status: MATCH/MISMATCH

- Status: PASS/FAIL (ALL verifications required)
```

**BLOCKING:** This is a user-specified critical gate. Cannot proceed until PASS.

---

### Task 4.4: Validation Gate - Multi-Turn Conversation

**GATE_MULTI_1: Multiple Back-and-Forth Exchanges**

This is a **USER-SPECIFIED CRITICAL GATE**.

**Requirement:** Multiple back-and-forth exchanges within a session work correctly.

**Test Procedure:**
1. Use existing session from Task 4.3
2. Send message 1: "List the MCP servers"
3. Wait for response, verify correctness
4. Send message 2: "Tell me about the first one in detail"
5. Wait for response, verify it references previous context
6. Send message 3: "How do I add a new one?"
7. Wait for response, verify coherent multi-turn conversation

**Evidence Required:**

```
EVIDENCE_4.4_GATE_MULTI_1:
- Type: iOS Simulator Screenshot Series (4 screenshots)

Screenshot 1 - Message 1 Exchange:
- Shows: "List the MCP servers" + response
- Must Verify:
  - [ ] User message visible
  - [ ] Assistant response lists MCP servers
  - [ ] Data matches MCP tab
- Filename: evidence_4.4a_turn1.png

Screenshot 2 - Message 2 Exchange:
- Shows: "Tell me about the first one" + response
- Must Verify:
  - [ ] Previous messages still visible
  - [ ] Response references specific server from turn 1
  - [ ] Context maintained
- Filename: evidence_4.4b_turn2.png

Screenshot 3 - Message 3 Exchange:
- Shows: "How do I add a new one?" + response
- Must Verify:
  - [ ] All 3 exchanges visible
  - [ ] Response provides relevant instructions
  - [ ] Conversation coherent
- Filename: evidence_4.4c_turn3.png

Screenshot 4 - Full Conversation:
- Shows: Scrolled view of entire conversation
- Must Verify:
  - [ ] 3 user messages
  - [ ] 3 assistant responses
  - [ ] All properly styled
  - [ ] Timestamps visible
- Filename: evidence_4.4d_full_conversation.png

- Status: PASS/FAIL (ALL 4 screenshots required)
```

**BLOCKING:** This is a user-specified critical gate. Cannot proceed until PASS.

---

### Task 4.5: Add Session Persistence to Backend

**Sub-Agent Assignment:** SUB-AGENT ALPHA (Backend)

**File:** `Sources/ILSBackend/Controllers/SessionController.swift`

```swift
import Vapor
import Fluent
import ILSShared

struct SessionController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let sessions = routes.grouped("api", "v1", "sessions")

        sessions.get(use: listSessions)
        sessions.post(use: createSession)
        sessions.get(":sessionId", use: getSession)
        sessions.delete(":sessionId", use: deleteSession)
        sessions.post(":sessionId", "chat", use: chat)
    }

    // GET /api/v1/sessions
    func listSessions(req: Request) async throws -> APIResponse<[SessionDTO]> {
        let sessions = try await SessionModel.query(on: req.db)
            .with(\.$project)
            .with(\.$messages)
            .sort(\.$updatedAt, .descending)
            .all()

        let dtos = sessions.map { session in
            SessionDTO(
                id: session.id!,
                project: session.project.map { ProjectDTO(id: $0.id!, name: $0.name, path: $0.path) },
                createdAt: session.createdAt!,
                updatedAt: session.updatedAt!,
                messageCount: session.messages.count
            )
        }

        return APIResponse(success: true, data: dtos)
    }

    // POST /api/v1/sessions
    func createSession(req: Request) async throws -> APIResponse<SessionDTO> {
        struct CreateRequest: Content {
            let projectPath: String
        }

        let input = try req.content.decode(CreateRequest.self)

        // Find or create project
        let project: ProjectModel
        if let existing = try await ProjectModel.query(on: req.db)
            .filter(\.$path == input.projectPath)
            .first() {
            project = existing
        } else {
            let name = URL(fileURLWithPath: input.projectPath).lastPathComponent
            project = ProjectModel(name: name, path: input.projectPath)
            try await project.save(on: req.db)
        }

        // Create session
        let session = SessionModel(projectId: project.id!)
        try await session.save(on: req.db)

        let dto = SessionDTO(
            id: session.id!,
            project: ProjectDTO(id: project.id!, name: project.name, path: project.path),
            createdAt: session.createdAt!,
            updatedAt: session.updatedAt!,
            messageCount: 0
        )

        return APIResponse(success: true, data: dto)
    }

    // GET /api/v1/sessions/:sessionId
    func getSession(req: Request) async throws -> APIResponse<SessionDetailDTO> {
        guard let sessionId = req.parameters.get("sessionId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }

        guard let session = try await SessionModel.query(on: req.db)
            .filter(\.$id == sessionId)
            .with(\.$project)
            .with(\.$messages) { $0.sort(\.$createdAt) }
            .first() else {
            throw Abort(.notFound, reason: "Session not found")
        }

        let messages = session.messages.map { msg in
            ChatMessageDTO(
                id: msg.id!,
                role: msg.role,
                content: msg.content,
                timestamp: msg.createdAt!,
                toolUse: msg.toolUseName.map { name in
                    ChatMessageDTO.ToolUseDTO(
                        name: name,
                        input: msg.toolUseInput ?? "",
                        output: msg.toolUseOutput,
                        status: msg.toolUseStatus ?? "completed"
                    )
                }
            )
        }

        let dto = SessionDetailDTO(
            id: session.id!,
            project: session.project.map { ProjectDTO(id: $0.id!, name: $0.name, path: $0.path) },
            createdAt: session.createdAt!,
            updatedAt: session.updatedAt!,
            messages: messages
        )

        return APIResponse(success: true, data: dto)
    }

    // DELETE /api/v1/sessions/:sessionId
    func deleteSession(req: Request) async throws -> APIResponse<Bool> {
        guard let sessionId = req.parameters.get("sessionId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }

        guard let session = try await SessionModel.find(sessionId, on: req.db) else {
            throw Abort(.notFound, reason: "Session not found")
        }

        try await session.delete(on: req.db)
        return APIResponse(success: true, data: true)
    }

    // POST /api/v1/sessions/:sessionId/chat (SSE Streaming)
    func chat(req: Request) async throws -> Response {
        guard let sessionId = req.parameters.get("sessionId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid session ID")
        }

        struct ChatRequest: Content {
            let content: String
        }

        let input = try req.content.decode(ChatRequest.self)

        // Verify session exists
        guard let session = try await SessionModel.find(sessionId, on: req.db) else {
            throw Abort(.notFound, reason: "Session not found")
        }

        // Save user message
        let userMessage = MessageModel(
            sessionId: sessionId,
            role: "user",
            content: input.content
        )
        try await userMessage.save(on: req.db)

        // Set up SSE response
        let response = Response(status: .ok)
        response.headers.contentType = HTTPMediaType(type: "text", subType: "event-stream")
        response.headers.add(name: .cacheControl, value: "no-cache")
        response.headers.add(name: .connection, value: "keep-alive")

        // Get Claude executor service
        let executor = req.application.claudeExecutor

        response.body = .init(asyncStream: { writer in
            do {
                // Execute Claude command with streaming
                for try await event in executor.execute(
                    projectPath: session.$project.id.map { _ in session.project?.path ?? "" } ?? "",
                    message: input.content,
                    sessionId: sessionId
                ) {
                    let eventData: String
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601

                    switch event {
                    case .text(let content):
                        let data = try encoder.encode(["content": content])
                        eventData = "event: text\ndata: \(String(data: data, encoding: .utf8)!)\n\n"

                    case .thinking(let content):
                        let data = try encoder.encode(["content": content])
                        eventData = "event: thinking\ndata: \(String(data: data, encoding: .utf8)!)\n\n"

                    case .toolUse(let name, let input):
                        let data = try encoder.encode(["name": name, "input": input])
                        eventData = "event: tool_use\ndata: \(String(data: data, encoding: .utf8)!)\n\n"

                    case .toolResult(let id, let output, let isError):
                        let data = try encoder.encode(["toolUseId": id, "output": output, "isError": isError] as [String: Any])
                        eventData = "event: tool_result\ndata: \(String(data: data, encoding: .utf8)!)\n\n"

                    case .error(let message):
                        let data = try encoder.encode(["message": message])
                        eventData = "event: error\ndata: \(String(data: data, encoding: .utf8)!)\n\n"

                    case .done(let fullResponse):
                        // Save assistant message
                        let assistantMessage = MessageModel(
                            sessionId: sessionId,
                            role: "assistant",
                            content: fullResponse
                        )
                        try await assistantMessage.save(on: req.db)

                        eventData = "event: done\ndata: {}\n\n"
                    }

                    try await writer.write(.buffer(.init(string: eventData)))
                }
            } catch {
                let errorData = "event: error\ndata: {\"message\": \"\(error.localizedDescription)\"}\n\n"
                try? await writer.write(.buffer(.init(string: errorData)))
            }

            try await writer.write(.end)
        })

        return response
    }
}

// MARK: - DTOs

struct SessionDTO: Content {
    let id: UUID
    let project: ProjectDTO?
    let createdAt: Date
    let updatedAt: Date
    let messageCount: Int
}

struct SessionDetailDTO: Content {
    let id: UUID
    let project: ProjectDTO?
    let createdAt: Date
    let updatedAt: Date
    let messages: [ChatMessageDTO]
}

struct ProjectDTO: Content {
    let id: UUID
    let name: String
    let path: String
}

struct ChatMessageDTO: Content {
    let id: UUID
    let role: String
    let content: String
    let timestamp: Date
    let toolUse: ToolUseDTO?

    struct ToolUseDTO: Content {
        let name: String
        let input: String
        let output: String?
        let status: String
    }
}
```

**Validation Criteria:**
- [ ] File compiles without errors
- [ ] All endpoints respond correctly
- [ ] SSE streaming works
- [ ] Messages persisted to database

**Evidence Required:**

```
EVIDENCE_4.5:
- Type: cURL Tests + Build Log

Test 1 - Create Session:
curl -X POST http://localhost:8080/api/v1/sessions \
  -H "Content-Type: application/json" \
  -d '{"projectPath":"~/test-project"}'

Expected: {"success":true,"data":{"id":"...","project":{...},...}}
Actual: [PASTE OUTPUT]

Test 2 - List Sessions:
curl http://localhost:8080/api/v1/sessions | jq

Expected: Array of sessions
Actual: [PASTE OUTPUT]

Test 3 - Get Session with Messages:
curl http://localhost:8080/api/v1/sessions/{id} | jq

Expected: Session with messages array
Actual: [PASTE OUTPUT]

Test 4 - Chat Streaming:
curl -X POST http://localhost:8080/api/v1/sessions/{id}/chat \
  -H "Content-Type: application/json" \
  -H "Accept: text/event-stream" \
  -d '{"content":"Hello"}'

Expected: SSE events (text, done)
Actual: [PASTE OUTPUT]

- Status: PASS/FAIL (ALL 4 tests must pass)
```

**BLOCKING:** Cannot proceed to Gate Check 4 until PASS

---

</phase_4>

<gate_check_4>

## GATE CHECK 4: Chat/Session Integration Phase

**OVERALL STATUS: PENDING**

| Gate | Requirement | Status |
|------|-------------|--------|
| 4.1 | ChatView renders | PENDING |
| **GATE_CHAT_1** | Slash commands work | PENDING |
| **GATE_SESSION_1** | New session shows system data | PENDING |
| **GATE_MULTI_1** | Multi-turn conversation works | PENDING |
| 4.5 | Backend session persistence | PENDING |

```
GATE_CHECK_4 (USER-CRITICAL):
- ChatView Compiles: PENDING
- Slash Commands Display: PENDING
- Session Creation Works: PENDING
- System Data Accessible: PENDING
- Multi-turn Context: PENDING
- Backend Endpoints: PENDING
- SSE Streaming: PENDING

PROCEED TO COMPLETION: Only if ALL = PASS
```

**CRITICAL:** Gates CHAT_1, SESSION_1, and MULTI_1 are user-specified requirements. Project is NOT complete without these passing.

</gate_check_4>

---

## Evidence Checklist Summary

```
COMPLETE EVIDENCE MANIFEST:

Phase 0 - Environment Setup:
□ EVIDENCE_0.1 - Directory tree output
□ EVIDENCE_0.2 - Package resolve output
□ EVIDENCE_0.3 - Xcode setup screenshot

Phase 1 - Shared Models:
□ EVIDENCE_1.1 - Session/Project models build
□ EVIDENCE_1.2 - StreamMessage models build
□ EVIDENCE_1.3 - Skill model build
□ EVIDENCE_1.4 - MCPServer/Plugin models build
□ EVIDENCE_1.5 - ClaudeConfig model build
□ EVIDENCE_1.6 - API DTOs build
□ GATE_CHECK_1 - Final shared models build

Phase 2A - Backend:
□ EVIDENCE_2A.5 - All controllers compile
□ EVIDENCE_2A.7 - All cURL tests pass
□ GATE_CHECK_2A - All endpoints verified

Phase 2B - Design System:
□ EVIDENCE_2B.2 - Theme compilation
□ GATE_CHECK_2B - Design system complete

□ GATE_CHECK_2 - Sync point (both 2A and 2B pass)

Phase 3 - iOS Views:
□ EVIDENCE_3.1 - App entry point
□ EVIDENCE_3.2 - ServerConnectionView
□ EVIDENCE_3.3 - DashboardView
□ EVIDENCE_3.4a - SkillsListView
□ EVIDENCE_3.4b - SkillDetailView
□ EVIDENCE_3.5 - MCPServerListView
□ EVIDENCE_3.6 - PluginMarketplaceView
□ EVIDENCE_3.7 - APIClient build
□ GATE_CHECK_3 - All views verified

Phase 4 - Chat/Session Integration:
□ EVIDENCE_4.1 - ChatView renders
□ EVIDENCE_4.2_GATE_CHAT_1 - Slash commands (3 screenshots)
□ EVIDENCE_4.3_GATE_SESSION_1 - Session with system data (3 screenshots + API)
□ EVIDENCE_4.4_GATE_MULTI_1 - Multi-turn conversation (4 screenshots)
□ EVIDENCE_4.5 - Backend session controller (4 cURL tests)
□ GATE_CHECK_4 - All chat/session gates verified

TOTAL EVIDENCE ARTIFACTS REQUIRED: 40+
```

---

## Evidence Checklist Summary

```
COMPLETE EVIDENCE MANIFEST:

Phase 0 - Environment Setup:
□ EVIDENCE_0.1 - Directory tree output
□ EVIDENCE_0.2 - Package resolve output
□ EVIDENCE_0.3 - Xcode setup screenshot

Phase 1 - Shared Models:
□ EVIDENCE_1.1 - Session/Project models build
□ EVIDENCE_1.2 - StreamMessage models build
□ EVIDENCE_1.3 - Skill model build
□ EVIDENCE_1.4 - MCPServer/Plugin models build
□ EVIDENCE_1.5 - ClaudeConfig model build
□ EVIDENCE_1.6 - API DTOs build
□ GATE_CHECK_1 - Final shared models build

Phase 2A - Backend:
□ EVIDENCE_2A.5 - All controllers compile
□ EVIDENCE_2A.7 - All cURL tests pass
□ GATE_CHECK_2A - All endpoints verified

Phase 2B - Design System:
□ EVIDENCE_2B.2 - Theme compilation
□ GATE_CHECK_2B - Design system complete

□ GATE_CHECK_2 - Sync point (both 2A and 2B pass)

Phase 3 - iOS Views:
□ [TO BE EXPANDED - 12+ view evidence items]

Phase 4 - Chat/Session Integration:
□ [TO BE EXPANDED - 8+ integration evidence items]

TOTAL EVIDENCE ARTIFACTS REQUIRED: 35+
```

---

## Failure Recovery Protocol

<failure_protocol>

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

</failure_protocol>

---

## Final Success Criteria

```
PROJECT COMPLETE WHEN:
1. All 4 phases have PASS status
2. All 35+ evidence artifacts collected
3. Backend responds correctly to all endpoints (cURL verified)
4. All iOS views render correctly (screenshot verified)
5. Chat streaming works end-to-end (screenshot series verified)
6. Session persistence works (app restart verified)
7. Dark theme with hot orange accent throughout
8. No compilation warnings or errors
9. No mock data in final product
```
