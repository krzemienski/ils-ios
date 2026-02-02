# Task: Create MCPServer and Plugin Models

## Description
Create models for MCP (Model Context Protocol) servers and plugins. These represent external tool integrations that extend Claude Code's capabilities.

## Background
MCP servers are defined in JSON configuration files (claude_desktop_config.json or .mcp.json) with command, args, and environment variables. Plugins are installable extensions from marketplaces that provide additional commands and agents.

## Reference Documentation
**Required:**
- Design: .sop/planning/design/detailed-design.md

**Additional References:**
- .sop/planning/research/claude-code-features.md (for MCP configuration format)

**Note:** You MUST read the detailed design document before beginning implementation.

## Technical Requirements
1. Create MCPServer struct with: name (as id), command, args, env, scope, status, configPath
2. Create ConfigScope enum: user, project, local, managed
3. Create ServerStatus enum: healthy, error, unknown
4. Create MCPConfiguration struct for parsing config files (mcpServers dictionary)
5. Create MCPServerDefinition struct for individual server config
6. Create Plugin struct with: id, name, description, marketplace, isInstalled, isEnabled, version, stars, source, commands, agents
7. Create PluginSource enum: official, community(repository)

## Dependencies
- Foundation framework

## Implementation Approach
1. Create Sources/ILSShared/Models/MCPServer.swift
2. Define MCPServer with computed id property (using name)
3. Define ConfigScope with displayName computed property
4. Define ServerStatus enum
5. Create MCPConfiguration and MCPServerDefinition for JSON parsing
6. Create Sources/ILSShared/Models/Plugin.swift
7. Define Plugin struct with all fields
8. Define PluginSource enum with associated values
9. Verify compilation with `swift build --target ILSShared`

## Acceptance Criteria

1. **MCPServer JSON Parsing**
   - Given a JSON config with mcpServers object
   - When decoding as MCPConfiguration
   - Then all servers are correctly parsed with command, args, env

2. **ConfigScope Display Names**
   - Given each ConfigScope case
   - When accessing displayName
   - Then it returns human-readable string (User, Project, Local, Managed)

3. **Plugin Source Handling**
   - Given a Plugin with community source
   - When encoding and decoding
   - Then repository string is preserved

4. **Compilation Success**
   - Given both model files
   - When running `swift build --target ILSShared`
   - Then build succeeds with zero errors

## Metadata
- **Complexity**: Low
- **Labels**: Models, Swift, Shared, MCP, Plugins
- **Required Skills**: Swift, Codable, Enums with associated values
