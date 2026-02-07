---
type: external-spec
source-type: mcp-server
source-id: Firecrawl
fetched: 2026-02-05T21:48:00Z
---

# Firecrawl MCP Server

## Summary
MCP server for web scraping, crawling, searching, and structured data extraction. Provides the most powerful web scraping and search capabilities available, with support for screenshots, JavaScript execution, and AI-powered extraction.

## Available Tools

| Tool | Description |
|------|-------------|
| firecrawl_scrape | Scrape content from a single URL with advanced options. Supports markdown, HTML, screenshots, links, branding formats. Most powerful single-page scraper. |
| firecrawl_map | Map a website to discover all indexed URLs. Best for URL discovery before scraping. |
| firecrawl_search | Search the web with optional content extraction. Supports search operators (site:, inurl:, intitle:, etc.). Best for finding information across multiple sites. |
| firecrawl_crawl | Start a crawl job on a website extracting content from all pages. Returns operation ID for status checking. |
| firecrawl_check_crawl_status | Check the status of a crawl job by ID. |
| firecrawl_extract | Extract structured information from web pages using LLM capabilities. Supports JSON schema for structured output. |
| firecrawl_agent | Autonomous web data gathering agent. Describe what data you want — agent searches, navigates, and extracts autonomously. |
| firecrawl_agent_status | Check the status of an agent job by ID. |

## Usage Patterns
- **Single page**: Use `firecrawl_scrape` with URL and format options
- **URL discovery**: Use `firecrawl_map` first, then `firecrawl_scrape` for specific pages
- **Web search**: Use `firecrawl_search` without formats first, then scrape relevant results
- **Multi-page**: Use `firecrawl_crawl` with depth/limit controls
- **Structured data**: Use `firecrawl_extract` with JSON schema
- **Complex research**: Use `firecrawl_agent` with natural language prompt

## Keywords
firecrawl web-scraping crawling search extraction screenshots markdown html structured-data autonomous-agent

## Related Components
- service-apiclient.md (HTTP request patterns)
- controller-projectscontroller.md (external data fetching)
