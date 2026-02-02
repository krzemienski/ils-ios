# Phase 04: Skills and MCP Server Management

This phase brings Claude Code's extensibility to iOS—browsing skills, viewing MCP servers, and understanding what capabilities are available. Users should see the same skills and MCP configurations they have on desktop, scanned from ~/.claude directory.

## Tasks

- [x] Implement FileSystemService for ~/.claude scanning:
  - Read `/Users/nick/Desktop/ils-ios/Sources/ILSBackend/Services/FileSystemService.swift`
  - Implement `scanSkills()` to find all .md files in ~/.claude/skills/ and subdirectories
  - Parse YAML frontmatter from skill files (name, description, tags)
  - Implement `scanMCPServers()` to read ~/.claude/mcp_servers.json
  - Handle missing directories/files gracefully with empty results
  - Cache scan results with configurable TTL (avoid rescanning on every request)

  **Completed 2026-02-02:** Implemented full FileSystemService with:
  - Added `tags` field to Skill model in ILSShared
  - `scanSkills()` recursively scans all subdirectories for .md files
  - `scanMCPServers()` reads from ~/.mcp.json and ~/.claude.json (legacy)
  - YAML frontmatter parsing extracts name, description, version, and tags (array or comma-separated)
  - Actor-based `FileSystemCache` with configurable TTL (default 30s)
  - `listSkills(bypassCache:)` and `readMCPServers(bypassCache:)` async methods
  - Controllers updated with `?refresh=true` query param to bypass cache
  - SkillsController supports `?search=term` to filter by name/description/tags

- [x] Complete SkillsController backend implementation:
  - Read `/Users/nick/Desktop/ils-ios/Sources/ILSBackend/Controllers/SkillsController.swift`
  - Implement `index()` to return all scanned skills
  - Implement `show()` to return single skill with full content
  - Add search/filter by name or tags query param
  - Return skills in SkillDTO format matching ILSShared model

  **Verified 2026-02-02:** SkillsController already fully implemented with:
  - `list()` endpoint at GET /skills returns all skills with cache-aware scanning
  - `get()` endpoint at GET /skills/:name returns single skill with full content
  - `?search=term` query param filters by name, description, and tags
  - `?refresh=true` query param bypasses FileSystemCache
  - Full CRUD operations (create, update, delete) also implemented
  - Uses Skill model from ILSShared with all required fields (name, description, version, tags, content, path, source)

- [ ] Complete MCPController backend implementation:
  - Read `/Users/nick/Desktop/ils-ios/Sources/ILSBackend/Controllers/MCPController.swift`
  - Implement `index()` to return all MCP server configurations
  - Implement `show()` to return single MCP server details
  - Parse mcp_servers.json format (name, command, args, env)
  - Return in MCPServerDTO format matching ILSShared model

- [ ] Update iOS SkillsListView and ViewModel:
  - Read `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Views/Skills/SkillsListView.swift`
  - Fetch skills from backend on view appear
  - Display skills in searchable list with name and description
  - Implement pull-to-refresh to rescan ~/.claude
  - Navigate to skill detail on tap

- [ ] Create SkillDetailView for viewing skill content:
  - Create view showing full skill markdown content
  - Render markdown with proper formatting (headers, code blocks, lists)
  - Show skill metadata (source file path, tags)
  - Add "Copy to Clipboard" action for skill content

- [ ] Update iOS MCPServerListView and ViewModel:
  - Read `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Views/MCP/MCPServerListView.swift`
  - Fetch MCP servers from backend on view appear
  - Display server name, command, and status indicator
  - Show configuration details (args, environment variables)
  - Implement pull-to-refresh to rescan

- [ ] Test skills and MCP scanning end-to-end:
  - Ensure ~/.claude/skills/ has at least one .md skill file
  - Ensure ~/.claude/mcp_servers.json exists (even if empty array)
  - Start backend and run iOS app
  - Navigate to Skills tab - verify skills appear
  - Navigate to MCP tab - verify servers appear
  - Modify a skill file and pull-to-refresh - verify update appears
