# Task: Create ClaudeConfig Model

## Description
Create the ClaudeConfig model for parsing and editing Claude Code's JSON configuration files. This model represents settings.json and related config files with their various configuration options.

## Background
Claude Code uses JSON configuration files at different scopes (user, project, local). The config includes API settings, model preferences, permissions, environment variables, and MCP server configurations.

## Reference Documentation
**Required:**
- Design: .sop/planning/design/detailed-design.md

**Additional References:**
- .sop/planning/research/claude-code-features.md (for config file structure)

**Note:** You MUST read the detailed design document before beginning implementation.

## Technical Requirements
1. Create ClaudeConfig struct with all known config fields
2. Include fields: apiKey, model, permissions, env, mcpServers, hooks, etc.
3. Create ConfigPermissions struct for permission settings
4. Create HookConfig struct for hook definitions
5. Make all fields optional to handle partial configs
6. Ensure round-trip JSON encoding/decoding preserves unknown fields
7. All types must be Codable and Sendable

## Dependencies
- MCPServer models from Task 1.4
- Foundation framework

## Implementation Approach
1. Create Sources/ILSShared/Models/ClaudeConfig.swift
2. Define ClaudeConfig with optional fields for each known config key
3. Define nested structs for complex config sections (permissions, hooks)
4. Use CodingKeys for JSON key mapping where needed
5. Consider using AnyCodable for preserving unknown fields
6. Verify compilation with `swift build --target ILSShared`

## Acceptance Criteria

1. **Config Parsing**
   - Given a Claude settings.json file
   - When decoding as ClaudeConfig
   - Then known fields are correctly parsed

2. **Partial Config Support**
   - Given a config with only some fields set
   - When decoding
   - Then missing fields are nil, not errors

3. **Round-Trip Preservation**
   - Given a config JSON
   - When decoding and re-encoding
   - Then the structure is preserved

4. **Compilation Success**
   - Given the ClaudeConfig model
   - When running `swift build --target ILSShared`
   - Then build succeeds with zero errors

## Metadata
- **Complexity**: Medium
- **Labels**: Models, Swift, Shared, Configuration, Settings
- **Required Skills**: Swift, Codable, Optional handling, JSON
