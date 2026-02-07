---
type: external-spec
source-type: mcp-server
source-id: Context7
fetched: 2026-02-05T21:48:00Z
---

# Context7 MCP Server

## Summary
MCP server for retrieving up-to-date documentation and code examples for any programming library or framework. Provides library resolution and documentation querying capabilities.

## Available Tools

| Tool | Description |
|------|-------------|
| resolve-library-id | Resolves a package/product name to a Context7-compatible library ID. Must be called before query-docs. Returns matching libraries ranked by relevance, documentation coverage, and reputation. |
| query-docs | Retrieves and queries up-to-date documentation and code examples from Context7 for any programming library or framework. Requires a valid library ID from resolve-library-id. |

## Usage Pattern
1. Call `resolve-library-id` with library name and query context
2. Use returned library ID (format: `/org/project`) with `query-docs`
3. Max 3 calls per question to avoid excessive usage

## Keywords
context7 documentation library framework reference docs code-examples api-docs

## Related Components
- service-apiclient.md (API patterns from docs)
- service-claudeexecutorservice.md (Claude SDK documentation)
- helper-configure.md (Vapor framework docs)
