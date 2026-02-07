# Auto-Claude Specs Implementation Plan

## Approach
- Implement ALL unique specs (dedup 059-082 overlaps with 024-048)
- Validate EACH feature with simulator screenshot + visual inspection
- Batch related specs together for efficiency

## Duplicate Mapping (implement once under original number)
| Dup | Original | Name |
|-----|----------|------|
| 052 | 001 | Unified Dashboard |
| 064 | 034 | README |
| 065 | 035 | SwiftDoc comments |
| 066 | 036 | FileSystemService docs |
| 067 | 037 | API endpoint reference |
| 068 | 038 | ClaudeExecutor docs |
| 069 | 028 | Consolidate models |
| 070 | 044 | Split FileSystemService |
| 071 | 043 | Batch stream updates |
| 072 | 041 | Equatable ChatMessage |
| 073 | 040 | SSEClient cancellation |
| 074 | 039 | Reuse JSON coders |
| 080 | 042 | Response caching |
| 081 | 047 | Base ViewModel |
| 082 | 048 | Simplify convertChunk |

## Phase 1: UI Polish (Quick Wins)
- [x] 024: Search filtering (already done - Skills, MCP, Plugins have .searchable)
- [x] 025: Swipe actions (already done - all list views have .swipeActions)
- [x] 027: Error states with ContentUnavailableView (already done)
- [x] 061: Context menus (already done - Sessions, Projects, Skills, MCP have .contextMenu)
- [ ] 026: Extract StatusBadge component
- [ ] 029: VoiceOver accessibility
- [ ] 030: Delete confirmation dialogs
- [ ] 031: Error alerts
- [ ] 032: Skeleton loading states
- [ ] 033: Haptic feedback
- [ ] 059: Loading state on form submit buttons
- [ ] 060: Global connection status banner
- [ ] 062: Toast notification pattern
- [ ] 063: Press state feedback on dashboard cards

## Phase 2: Features
- [ ] 003: Skill detail view
- [ ] 005: MCP server detail view
- [ ] 006: Local server connection setup
- [ ] 007: Visual MCP config editor
- [ ] 010: Skill browser/discovery
- [ ] 011: One-tap skill installation
- [ ] 012: Real-time MCP health monitoring
- [ ] 013: Push notifications for MCP status
- [ ] 015: Plugin marketplace browser
- [ ] 016: Plugin install/management
- [ ] 017: Bulk MCP import/export
- [ ] 018: Batch MCP operations
- [ ] 021: Config sharing via cloud sync
- [ ] 023: Config automation scripts
- [ ] 049: GitHub skills search
- [ ] 050: MCP server add/edit
- [ ] 051: Session state persistence
- [ ] 054: Session templates
- [ ] 056: Config file editor
- [ ] 075: Pagination for lists
- [ ] 076: Enable/disable toggle for skills
- [ ] 077: Duplicate/clone projects
- [ ] 078: Copy to clipboard with toast
- [ ] 079: Refresh/cache bypass

## Phase 3: Infrastructure Specs (User says no skips)
- [ ] 008: SSH remote server connection
- [ ] 009: Remote Claude Code config management
- [ ] 014: Project configuration profiles
- [ ] 019: Config override visualization
- [ ] 020: Config history and diff
- [ ] 022: Multi-server fleet management
- [ ] 055: SSH connection to remote servers
- [ ] 057: Logging/analytics infrastructure
- [ ] 058: Offline mode / local caching

## Phase 4: Code Quality / Docs
- [ ] 028: Consolidate API types
- [ ] 034: Root README
- [ ] 035: SwiftDoc comments
- [ ] 036: FileSystemService docs
- [ ] 037: API endpoint reference
- [ ] 038: ClaudeExecutor docs
- [ ] 039: Reuse JSON encoder/decoder
- [ ] 040: Fix SSEClient cancellation
- [ ] 041: Equatable for ChatMessage
- [ ] 042: Response caching
- [ ] 043: Batch stream updates
- [ ] 044: Split FileSystemService
- [ ] 047: Base ViewModel extraction
- [ ] 048: Simplify convertChunk

## Validation
- Build and run in simulator after each feature
- Capture screenshot evidence
- Visually inspect each screenshot
- Only mark complete after verification
