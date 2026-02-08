# Competitive Analysis: AI Coding Assistant Mobile Interfaces

**Analysis Date:** February 7, 2026
**Purpose:** Inform ILS iOS app redesign decisions based on competitive mobile AI assistant UX patterns

---

## Executive Summary

### Key Findings

1. **No competitors have separate "Projects" screens on mobile** - Projects are either desktop-only (Claude) or integrated into conversation organization (ChatGPT)
2. **Bottom tab navigation dominates iOS AI apps** - 3-5 tabs in thumb zone is the standard
3. **Tool calls are now prominently displayed** - Real-time visibility into AI actions is a 2026 expectation
4. **iPad apps are getting dedicated redesigns** - Not just scaled iPhone layouts (see Perplexity)
5. **Adaptive/predictive UI is the trend** - AI anticipating user needs, not just responding

### Strategic Recommendations for ILS iOS

- **Collapse Projects into Sessions**: Don't replicate the desktop hierarchy; mobile users want quick access to conversations
- **Adopt bottom tab bar**: Dashboard, Sessions, System, Settings (4 tabs max)
- **Show tool execution transparently**: Real-time tool call indicators with collapsible details
- **Design for iPad from day one**: Split view with persistent sidebar
- **Use accent colors for entities**: Follow ChatGPT's personalization approach

---

## 1. ChatGPT iOS App

**Developer:** OpenAI
**Latest Updates:** February 2026

### Navigation Pattern
- **Collapsible sidebar** on the left with conversation threads
- **Search bar** to filter conversations
- **New chat button (+)** prominently placed
- **Bottom profile icon** for settings/personalization

### Session/Conversation Management
- **Projects feature** (launched Dec 2025, expanded to iOS Jan 2026)
  - Folders that group related chats + files
  - Customizable with colors and icons
  - **No separate Projects screen** - accessed via sidebar organization
- **Sidebar organization:**
  - Recent conversations (chronological)
  - Grouped by Projects (if enabled)
  - Search/filter capabilities
- **Group chats** (Nov 2025) - Up to 20 users in shared conversations
- **Conversation sync** across all devices

### Chat UI
- **Message bubbles** with user/assistant distinction
- **Code blocks** with syntax highlighting (markdown-based)
- **Copy buttons** on code blocks
- **Markdown rendering** for headings, lists, links, quotes
- Some rendering issues reported with complex markdown in large contexts

### Project Concept
- **Projects = folders for conversations + files**
- Accessible from sidebar, not a dedicated screen
- Can share entire projects with teams
- Desktop parity on iOS as of Jan 2026

### Theming
- **Dark mode** with system theme sync
- **Accent color customization** (affects bubbles, buttons, highlights)
- **Per-platform settings** (iOS settings don't sync to Android/web)

### iPad Support
- No specific redesign mentioned
- Likely uses standard responsive layout

### Unique Features
- **Voice mode** with 5 voice options
- **Health space** in sidebar (2026) for wellness conversations
- **Group chats** - collaborative AI sessions

**Sources:**
- [Comparing Conversational AI Tool User Interfaces 2025](https://intuitionlabs.ai/articles/conversational-ai-ui-comparison-2025)
- [ChatGPT Sidebar Redesign Guide](https://www.ai-toolbox.co/chatgpt-management-and-productivity/chatgpt-sidebar-redesign-guide)
- [Projects in ChatGPT Help Center](https://help.openai.com/en/articles/10169521-projects-in-chatgpt)
- [Updating Your Visual Experience](https://help.openai.com/en/articles/11958281-updating-your-visual-experience-on-chatgpt)

---

## 2. Claude iOS App

**Developer:** Anthropic
**Latest Updates:** January 2026 (Opus 4.6 release)

### Navigation Pattern
- **Conversation list** as primary view
- **No Projects management on mobile** (desktop/web only)
- iOS system app integration for actions (messages, calendar, reminders, health)

### Session/Conversation Management
- **Projects exist but are desktop-only for creation/management**
- Mobile users can **participate in Project conversations** but not create/configure them
- **Real-time sync** across devices (200K context window)
- Conversations listed chronologically

### Chat UI
- **Artifacts** - Standalone content in dedicated window
  - Supports interactive apps, tools, visualizations
  - Available on mobile (2026)
  - Separate from main conversation flow
- **Extended thinking mode** for deeper reasoning
- **Markdown + code rendering**
- **Voice mode** with 5 voice options

### Project Concept
- **Desktop-only administrative function**
- Projects group conversations + custom instructions + knowledge
- Mobile limitation is a known UX gap

### Theming
- Standard dark/light mode (details not specified in search results)

### iPad Support
- **Artifacts Gallery** optimized for larger screens
- No dedicated iPad redesign reported

### Unique Features
- **MCP integration** (Model Context Protocol) on iOS
- **Memory feature** - persistent context across conversations
- **iOS system app hooks** - draft messages, find locations, etc.
- **Artifacts** - Interactive content generation

**Sources:**
- [Using Claude with iOS Apps](https://support.claude.com/en/articles/11869619-using-claude-with-ios-apps)
- [Claude Pro Mobile App Features Guide](https://aionx.co/claude-ai-reviews/claude-pro-mobile-app-features/)
- [Use Artifacts Help Center](https://support.claude.com/en/articles/9487310-what-are-artifacts-and-how-do-i-use-them)

---

## 3. Cursor AI Code Editor

**Developer:** Anysphere
**Platform:** Desktop-first, mobile web/agents in beta

### Navigation Pattern
- **Desktop IDE** with integrated chat panel
- **Web app + Slack bot** for mobile/remote access (2026)
- **Shared sessions** for pair programming (Pro feature)

### Session Management
- **Context windows** that can be summarized with `/summarize` command
- **Recommendation: Start new sessions** for separate tasks to avoid context pollution
- **Background Agents** (0.50 release) - async task execution
- **Memory features** maintain context across sessions

### Chat UI
- **Cmd+K interface** for multi-file edits
- **Tab completion** inline in code
- **Composer 2.0** with "Plan Mode" (2026) - AI outlines steps before executing
- **Autonomy slider** - control AI independence level

### Project Concept
- **Codebase-aware** - entire project is context
- No separate "projects" UI element
- **Background Agents** handle parallel tasks

### Theming
- IDE-standard themes

### iPad Support
- Not a mobile-native app
- Web interface accessible on tablets

### Unique Features
- **Agentic coding** - AI can work independently in background
- **Multi-file awareness** and edits
- **Plan then execute** workflow

**Sources:**
- [Cursor Features](https://cursor.com/features)
- [Cursor Changelog 2026](https://blog.promptlayer.com/cursor-changelog-whats-coming-next-in-2026/)
- [Cursor AI vs GitHub Copilot 2026](https://dev.to/thebitforge/cursor-ai-vs-github-copilot-which-2026-code-editor-wins-your-workflow-1019)

---

## 4. Windsurf (Codeium)

**Developer:** Codeium (rebranded to Windsurf)
**Platform:** Desktop IDE + plugins

### Navigation Pattern
- **Windsurf Editor** (agentic IDE) for desktop
- **Windsurf Plugins** across VS Code, JetBrains, Vim, Xcode
- **No dedicated mobile app** mentioned

### Session Management
- **Cascade** - agentic AI that understands codebase
- Can suggest multi-file edits, run terminal commands
- Works alongside developer (copilot model)

### Chat UI
- Integrated within IDE
- **Multi-file preview** before applying changes

### Project Concept
- Codebase-level awareness
- No separate project organization UI

### Theming
- IDE-standard

### iPad Support
- Not mobile-focused

### Unique Features
- **Cascade technology** - contextual awareness
- **Free tier** competitive with paid alternatives
- **Cross-IDE consistency** via plugins

**Sources:**
- [Windsurf Review 2026](https://vibecoding.app/blog/windsurf-review)
- [Windsurf Editor](https://codeium.com/windsurf)

---

## 5. GitHub Copilot

**Developer:** GitHub/Microsoft
**Platform:** IDE + GitHub Mobile

### Navigation Pattern
- **GitHub Mobile integration** - chat interface within mobile app
- **IDE-first** for desktop (VS Code, Visual Studio, JetBrains)
- **Web chat** on github.com

### Session Management
- **Chat sessions** saved in IDE
- `/clear` command to reset context
- **Session persistence** across IDE restarts

### Chat UI (February 2026 Updates)
- **Tool call visibility** - Real-time display of actions Copilot is taking
  - See steps being executed
  - Course-correct if failures occur
  - View references per tool call
- **Export conversations** as JSON or Markdown
- **Inline chat** in editor for contextual assistance
- **MCP apps integration** for richer tool-driven interactions

### Project Concept
- **Repository-scoped** understanding
- No separate projects UI

### Theming
- Follows IDE/system theme

### iPad Support
- Via GitHub Mobile app (not IDE)

### Unique Features
- **Native GitHub integration** - understands repos, PRs, issues
- **Agent Mode** (2026) - autonomous teammate capability
- **Real-time tool execution transparency**
- **MCP support** in VS Code

**Sources:**
- [GitHub Copilot Chat in GitHub Mobile](https://github.blog/news-insights/product-news/github-copilot-chat-in-github-mobile/)
- [Showing Tool Calls and Improvements](https://github.blog/changelog/2026-02-04-showing-tool-calls-and-other-improvements-to-copilot-chat-on-the-web/)
- [GitHub Copilot in VS Code v1.109](https://github.blog/changelog/2026-02-04-github-copilot-in-visual-studio-code-v1-109-january-release/)

---

## 6. Replit Mobile App

**Developer:** Replit
**Platform:** Web + Mobile (iOS/Android)

### Navigation Pattern
- **Menu icon** for conversation history
- **New chat button** to start sessions
- Mobile app for "vibe coding" (Jan 2026)

### Session Management
- **Checkpoints** - comprehensive snapshots of work
  - Workspace contents
  - AI conversation context
  - Connected databases
- Agent creates checkpoints when finishing requests
- **Conversation menu** - select previous chats or start new

### Chat UI
- **Natural language prompts** → working apps
- **Replit Agent** interface for app creation
- Supports iOS app deployment (React Native + Expo)

### Project Concept
- **Agent-managed apps** are the "project"
- Checkpoints preserve project state + conversation context
- No separate projects screen

### Theming
- Not specified in search results

### iPad Support
- Mobile-optimized interface

### Unique Features
- **Mobile Apps on Replit** - build iOS apps from prompts
- **Direct App Store submission** workflow
- **Agent 3** (2026) - autonomous 200-minute coding sessions
- **Self-healing code** capabilities
- **Checkpoint system** for state preservation

**Sources:**
- [Replit Launches AI Mobile App Builder](https://www.cnbc.com/2026/01/15/ai-startup-replit-launches-feature-to-vibe-code-mobile-apps.html)
- [Replit Agent 3 2026](https://leaveit2ai.com/ai-tools/code-development/replit-agent-v3)
- [Replit Docs - Agent](https://docs.replit.com/replitai/agent)

---

## 7. Perplexity

**Developer:** Perplexity AI
**Platform:** iOS, iPad (redesigned Dec 2025)

### Navigation Pattern
- **Redesigned sidebar** (iOS, Dec 2025) - less busy, flatter navigation
- **Search bar** as primary interaction
- **Larger side panel on iPad** - persistent, readable

### Session/Conversation Management
- **Thread follow-ups** for deeper understanding
- **Search and filter references** easily
- **Source-connected answers** with citation visualization
- No "projects" concept - research-focused

### Chat UI
- **Cited sources** for every answer
- **Pro Search & Deep Research** - searches hundreds of sources
- **Improved source display** - connections between sources and answers visible
- **Quizzes and flashcards** generation (Jan 2026)

### Project Concept
- **Perplexity Labs** for reports and projects
- Not a traditional project hierarchy

### Theming
- Clean, research-focused design
- Dark/light mode support (assumed)

### iPad Support ⭐
- **Dedicated iPad redesign** (Dec 2025)
- **Split-view optimized**
- **Native iPadOS features** leveraged
- **Research tools focus** for students/professionals
- Larger sidebar for revisiting searches, comparing answers

### Unique Features
- **Research-first** design (not general chat)
- **Citation transparency** - sources are first-class
- **Assistant** for drafting emails, scheduling
- **Deep Research** feature for comprehensive analysis

**Sources:**
- [Perplexity's Revamped iPad App](https://9to5mac.com/2025/12/16/perplexitys-revamped-ipad-app-doubles-down-on-research-tools-and-a-more-native-experience/)
- [Perplexity AI 2026 Complete Guide](https://notiongraffiti.com/perplexity-ai-guide-2026/)

---

## 8. v0 by Vercel

**Developer:** Vercel
**Platform:** Web + iOS app (2026)

### Navigation Pattern
- **iOS app** for building anywhere
- Web-first interface

### Session Management
- Conversation-based with live preview
- **Iterative refinement** - "make this button green" style commands

### Chat UI
- **Visual controls** alongside chat
- **Live preview** of generated UI
- **Instant updates** from natural language commands
- Code generation with **shadcn/ui + Tailwind CSS**

### Project Concept
- **Full-stack builder** (2026 evolution)
- Generates APIs, databases, server-side logic
- Deploy-ready Next.js applications

### Theming
- UI-generation-focused
- Visual customization via chat

### iPad Support
- iOS app suggests mobile/tablet support

### Unique Features
- **Generative UI** from descriptions
- **"Vibe coding"** philosophy
- **Component-level editing** with visual controls
- **Full-stack in 2026** - not just frontend

**Sources:**
- [v0 by Vercel](https://v0.dev/)
- [v0 Review 2026](https://leaveit2ai.com/ai-tools/code-development/v0)
- [Maximizing Outputs with v0](https://vercel.com/blog/maximizing-outputs-with-v0-from-ui-generation-to-code-creation)

---

## 9. Bolt.new (StackBlitz)

**Developer:** StackBlitz
**Platform:** Web-based (launched Oct 2024)

### Navigation Pattern
- **Chat interface** as primary interaction
- **In-browser development environment** powered by WebContainers

### Session Management
- **Beta status** (actively improving based on feedback)
- Conversation-based with project state

### Chat UI
- **Natural language prompts** → full-stack apps
- AI has complete control: filesystem, node server, package manager, terminal, browser console
- **Multi-task commands** - "change color + add mobile responsiveness + restart server" in one go

### Project Concept
- **Complete app lifecycle** - creation to deployment
- **In-browser execution** (WebContainers)

### Theming
- Web-based development environment

### iPad Support
- Browser-based, accessible on tablets

### Unique Features
- **AI controls entire dev environment** (not just code generation)
- **Instant deployment** capability
- **Multi-framework support** (React, Vue, Svelte, Astro)
- **No setup required** - everything in browser

**Sources:**
- [Bolt AI Builder](https://bolt.new/)
- [Bolt.new Review 2025](https://www.designmonks.co/case-study/bolt-ai-app-builder-case-study)
- [GitHub - stackblitz/bolt.new](https://github.com/stackblitz/bolt.new)

---

## Cross-Platform Design Patterns Analysis

### Navigation Patterns for iOS AI Apps (2026)

| Pattern | Apps Using It | Notes |
|---------|---------------|-------|
| **Bottom Tab Bar** | ChatGPT, Perplexity | 3-5 tabs in thumb zone - iOS standard |
| **Collapsible Sidebar** | ChatGPT (left sidebar) | Desktop-style on mobile |
| **Menu Icon → History** | Replit | Hamburger menu for conversations |
| **Persistent Sidebar (iPad)** | Perplexity (iPad redesign) | Split view, always visible |

**Recommendation for ILS:** Bottom tab bar with 4 tabs: Dashboard, Sessions, System, Settings

---

### Session/Conversation Organization Strategies

| Strategy | Apps Using It | Mobile Implementation |
|----------|---------------|----------------------|
| **Chronological list** | Claude, Cursor | Simple recent-first |
| **Projects as folders** | ChatGPT | Sidebar groups, NOT separate screen |
| **Checkpoints/snapshots** | Replit | State preservation with context |
| **No organization** | v0, Bolt.new | Single-project focus |
| **Research threads** | Perplexity | Topic-based with citations |

**Key Finding:** NO competitor has a separate "Projects" screen on mobile. Projects are either:
- Desktop-only management (Claude)
- Sidebar folders (ChatGPT)
- Implicit in the app state (Replit checkpoints)

**Recommendation for ILS:** Integrate projects into session list. Use tags, colors, or folders in sidebar/list view.

---

### Chat UI: Code Blocks & Tool Calls

| Feature | Apps Using It | Implementation |
|---------|---------------|----------------|
| **Syntax highlighting** | ChatGPT, Claude, Copilot | Markdown code fences |
| **Copy button** | ChatGPT, v0 | Per code block |
| **Tool call visibility** | **GitHub Copilot (Feb 2026)** ⭐ | Real-time action display |
| **Artifacts panel** | Claude | Separate window for interactive content |
| **Live preview** | v0 | Side-by-side code + rendered UI |
| **Plan disclosure** | Cursor Composer 2.0, Cline | Show steps before execution |

**2026 Trend:** **Tool execution transparency is now expected**. Users want to see:
- What tool is being called
- Real-time progress
- Results/references per tool
- Ability to course-correct

**Recommendation for ILS:**
- ToolCallAccordion (already built) is aligned with 2026 standards
- Add real-time status indicators during execution
- Show collapsible details per tool call
- Allow stopping/canceling mid-execution

---

### Theming & Customization

| App | Dark Mode | Accent Colors | Custom Themes |
|-----|-----------|---------------|---------------|
| ChatGPT | ✅ System sync | ✅ Customizable | Per-platform settings |
| Claude | ✅ Standard | Unknown | Likely system standard |
| Perplexity | ✅ Standard | Research-focused palette | Minimal customization |
| GitHub Copilot | ✅ IDE theme | Follows IDE | IDE-controlled |

**Recommendation for ILS:**
- System dark/light mode sync
- Accent color customization for entity types (project, session, skill colors)
- Follow iOS design language (SF Pro font, native controls)

---

### iPad-Specific Design

| App | iPad Strategy | Key Features |
|-----|---------------|-------------|
| **Perplexity** ⭐ | Dedicated redesign (Dec 2025) | Split view, persistent sidebar, research tools |
| ChatGPT | Responsive layout | Likely scaled iPhone UI |
| Claude | Artifacts optimized | Some tablet considerations |
| v0 | iOS app (mobile/tablet) | Visual controls for larger screens |

**2026 Trend:** Apps are moving from "responsive iPhone layouts" to **dedicated iPad designs** with:
- Split-view multitasking
- Persistent sidebars (not collapsible)
- Stage Manager support
- Larger information density

**Recommendation for ILS:**
- Design iPad layout from day one
- Split view: Sessions list (left) + Chat view (right)
- Larger System monitoring dashboards on iPad
- Keyboard shortcuts for power users

---

### Multi-Agent / Team Views

| App | Multi-Agent Support | UI Pattern |
|-----|---------------------|-----------|
| ChatGPT | Group chats (up to 20 users) | Shared conversation threads |
| GitHub Copilot | Agent Mode (autonomous) | Single-agent with autonomy slider |
| Cursor | Background Agents | Parallel task execution |
| CrewAI | Multi-agent framework | Desktop orchestration |

**Finding:** Consumer AI apps (ChatGPT, Claude) don't show multi-agent UIs on mobile. It's either:
- **Group chat** (human + AI collaboration)
- **Single AI with background tasks** (hidden parallelism)

**Recommendation for ILS:**
- Don't try to visualize swarm/team agents on mobile UI (too complex)
- Show aggregate "AI is working on 3 tasks" indicator
- Let users see task results, not agent choreography

---

### Project → Session Hierarchy: How Competitors Handle It

| App | Hierarchy Model | Mobile Pattern |
|-----|-----------------|----------------|
| ChatGPT | Projects contain Conversations | Sidebar folders (same screen) |
| Claude | Projects contain Conversations | Desktop-only projects |
| Replit | Checkpoints contain Conversations | Single app = single context |
| Cursor | Sessions contain Context | No formal projects |
| Perplexity | Threads only | No projects concept |

**Critical Finding:**
- **Mobile users don't navigate project → session hierarchies**
- They want **flat, fast access to recent conversations**
- Projects are organizational metadata, not navigation structure

**Recommendation for ILS:**
- **Flatten the hierarchy on mobile**: Sessions list with project tags/colors
- **Filter/group by project** if needed, but don't require two taps to reach a chat
- **Projects screen** (if it exists) should be for browsing all projects, not navigating to sessions
  - Think: "Project detail view shows sessions within it"
  - Not: "Must tap project → then tap session"

---

## Unique Features Worth Studying

### 1. ChatGPT: Conversation Export
- Export chats as JSON or Markdown
- Useful for documentation, auditing
- **ILS opportunity:** Export session transcripts with tool calls

### 2. Claude: Artifacts
- Separate panel for generated content (apps, visualizations)
- Not mixed into chat bubbles
- **ILS opportunity:** If generating code/configs, show in separate panel

### 3. GitHub Copilot: Tool Call Transparency (Feb 2026)
- Real-time display of what AI is doing
- Course-correction if failures
- Per-tool references
- **ILS opportunity:** Already building this with ToolCallAccordion

### 4. Perplexity: Citation-First Design
- Sources are equally important as answers
- Visual connections between answers and sources
- **ILS opportunity:** Show which files/context informed AI decisions

### 5. Replit: Checkpoints
- Snapshot of workspace + conversation + data
- Restore to any point in development
- **ILS opportunity:** Session snapshots with project state

### 6. Cursor: Plan Mode
- AI outlines steps before executing
- User approves plan
- **ILS opportunity:** Show implementation plan before running agents

### 7. v0: Live Preview
- Code generation with instant visual feedback
- Iterative refinement via chat
- **ILS opportunity:** If generating UIs, show preview

---

## 2026 Mobile AI Design Trends

### 1. Adaptive & Predictive UIs
- **Trend:** AI predicts user needs, reshapes interface
- **Examples:**
  - Frequently-used actions move to easier reach
  - Menus adapt based on behavior
  - Context-aware suggestions
- **ILS Application:**
  - Suggest next actions in Dashboard
  - Predict which session user wants to resume
  - Smart project/skill recommendations

### 2. Progressive Disclosure
- **Trend:** Show complexity only when needed
- **Examples:**
  - Tool calls collapsed by default
  - Advanced options behind "More" buttons
  - Step-by-step onboarding
- **ILS Application:**
  - ToolCallAccordion (already doing this)
  - Advanced session options hidden initially
  - System details collapsed

### 3. AI Assistant Cards
- **Trend:** Separate cards/panels instead of chat bubbles
- **Examples:**
  - Claude Artifacts
  - Tool execution results in dedicated areas
- **ILS Application:**
  - System metrics as cards
  - Tool results in expandable sections
  - Thinking process in separate area

### 4. Transparency & Explainability
- **Trend:** Users want to see what AI is doing
- **Examples:**
  - GitHub Copilot tool call display
  - Cursor plan mode
  - Perplexity citations
- **ILS Application:**
  - Show which files informed decisions
  - Display tool execution steps
  - Citation/reference to codebase context

### 5. Modular Components
- **Trend:** Flexible grids, unconventional layouts
- **Examples:**
  - Buttons move for one-handed use
  - Interface elements fade when not needed
  - Context-aware positioning
- **ILS Application:**
  - Adaptive layouts for different tasks
  - Reachability-aware controls
  - Reduce motion support

---

## Competitive Positioning: Where ILS Can Stand Out

### Gaps in Current Market

1. **No mobile AI coding assistant focuses on localhost/backend integration**
   - Most are cloud services
   - ILS advantage: Local server management + AI

2. **No competitor shows system-level monitoring in AI chat context**
   - Cursor/Copilot focus on code
   - ChatGPT/Claude are general-purpose
   - ILS advantage: CPU/Memory/Processes + AI coding

3. **Most don't integrate MCP/plugin ecosystems visually**
   - Claude has MCP but UI is minimal
   - ILS advantage: MCP servers, plugins, skills as first-class entities

4. **iPad development tools are rare**
   - Most are desktop IDEs or phone apps
   - ILS advantage: Dedicated iPad coding experience

### Unique Value Propositions for ILS

1. **Unified Dev Environment Dashboard**
   - System metrics + AI chat + project management in one app
   - No competitor combines these

2. **Local-First with Cloud Integration**
   - Run backend locally, optionally expose via tunnel
   - Cursor/Copilot require cloud; ILS can be offline-capable

3. **Visual Tool/Plugin Management**
   - MCP servers, skills, plugins as browsable, installable entities
   - Most apps hide this complexity

4. **Conversation + Context Transparency**
   - Show why AI made decisions (which files, which context)
   - Perplexity does this for research; ILS can do it for code

5. **iPad-Optimized from Day One**
   - Most apps are iPhone-first with scaled layouts
   - ILS can compete with Perplexity's iPad-native approach

---

## Design Pattern Recommendations for ILS iOS

### Navigation Structure

```
Bottom Tab Bar (4 tabs):
┌─────────────────────────────────────────┐
│                                         │
│         [Main Content Area]             │
│                                         │
│                                         │
└─────────────────────────────────────────┘
┌───────┬──────────┬─────────┬──────────┐
│   🏠  │    💬    │   ⚙️   │    ⚙︎    │
│ Dash  │ Sessions │ System │ Settings │
└───────┴──────────┴─────────┴──────────┘
```

**Rationale:**
- iOS standard (bottom tabs in thumb zone)
- 4 tabs balances discoverability with simplicity
- No "Projects" tab (integrate into Sessions)

### Session List Design

```
Sessions Tab:
┌─────────────────────────────────────────┐
│  Search / Filter          [+ New]       │
├─────────────────────────────────────────┤
│  📘 Project Alpha   ●                   │
│  "Debugging auth flow"          2h ago  │
├─────────────────────────────────────────┤
│  📗 Project Beta                        │
│  "Add new API endpoint"        1d ago   │
├─────────────────────────────────────────┤
│  📘 Project Alpha   ●                   │
│  "Refactor database models"    3d ago   │
└─────────────────────────────────────────┘
```

**Features:**
- Project name + color as metadata (not hierarchy)
- Active session indicator (●)
- Last message preview
- Timestamp
- Swipe actions: Pin, Archive, Delete

### Chat View with Tool Calls

```
ChatView:
┌─────────────────────────────────────────┐
│  ← Project Alpha: "Debug auth"          │
├─────────────────────────────────────────┤
│  You: "Check the login endpoint"        │
│                                         │
│  Assistant:                             │
│  I'll analyze the auth code...         │
│                                         │
│  🔧 Tools Used (3)             [Expand] │
│  ├─ read_file: api/auth.ts     ✓       │
│  ├─ lsp_diagnostics            ✓       │
│  └─ grep: "login"              ✓       │
│                                         │
│  Found the issue in line 47...         │
│                                         │
├─────────────────────────────────────────┤
│  [Type a message...]            [Send]  │
└─────────────────────────────────────────┘
```

**Features:**
- Collapsed tool calls by default
- Expand to see details
- Real-time status (⏳ running, ✓ done, ✗ error)
- Markdown + code syntax highlighting in responses

### iPad Split View

```
iPad Layout:
┌──────────────┬────────────────────────────┐
│  Sessions    │  Chat View                 │
│  ─────────   │  ──────────                │
│              │                            │
│  📘 Alpha ●  │  🔧 Tools Used (3) ▼       │
│  Debug...    │  ├─ read_file ✓            │
│              │  ├─ lsp_diagnostics ✓      │
│  📗 Beta     │  └─ grep ✓                 │
│  Add API...  │                            │
│              │  The issue is in...        │
│  📘 Alpha    │                            │
│  Refactor... │  ```typescript             │
│              │  // Fixed code             │
│              │  ```                       │
│              │                            │
│  [Bottom     │  [Input field]             │
│   Tabs]      │                            │
└──────────────┴────────────────────────────┘
```

**Features:**
- Persistent session list (30-40% width)
- Tap session to load in right pane
- Bottom tabs still present (Dashboard, System, Settings)
- More vertical space for code blocks

### Dashboard Cards

```
Dashboard:
┌─────────────────────────────────────────┐
│  Recent Sessions                        │
│  ────────────────────────────            │
│  📘 Debug auth flow          [Resume]   │
│  📗 Add API endpoint         [Resume]   │
│                                         │
│  System Health               ───        │
│  🟢 CPU 23%  Memory 45%  Disk 60%       │
│                                         │
│  Quick Actions                          │
│  [New Session] [Browse Projects]        │
│  [System Monitor] [Install Plugin]      │
└─────────────────────────────────────────┘
```

**Features:**
- Glanceable status
- One-tap resume sessions
- Quick actions for common tasks
- System health at-a-glance

---

## Actionable Takeaways for ILS Redesign

### Must-Have (Table Stakes in 2026)

1. ✅ **Bottom tab navigation** (3-5 tabs)
2. ✅ **Dark mode with accent colors**
3. ✅ **Tool call transparency** (collapsible details)
4. ✅ **Markdown + syntax highlighting** in chat
5. ✅ **Real-time sync** across devices
6. ✅ **Search/filter conversations**

### Competitive Differentiators

1. 🎯 **System monitoring integrated with AI chat** (unique to ILS)
2. 🎯 **Local backend + Cloudflare tunnel management** (unique to ILS)
3. 🎯 **MCP/Plugin/Skill marketplace** as first-class UI
4. 🎯 **iPad-native split view** (match Perplexity quality)
5. 🎯 **Conversation context citations** (show which files informed AI)
6. 🎯 **Session checkpoints** with project state (like Replit)

### Design Decisions

| Question | Answer Based on Competitive Analysis |
|----------|--------------------------------------|
| Separate Projects screen? | **No** - integrate into Sessions with tags/colors |
| Sidebar or tabs? | **Bottom tabs** (iOS standard) |
| How to show tool calls? | **Collapsible accordion** with real-time status |
| iPad strategy? | **Dedicated split-view layout** (not scaled iPhone) |
| How to organize sessions? | **Chronological with project filters**, not project→session hierarchy |
| Theme customization? | **System dark/light + accent colors** per entity type |
| Multi-agent visualization? | **Aggregate progress indicator**, not detailed agent choreography |

### Avoid These Pitfalls

1. ❌ **Don't create desktop-style project hierarchy on mobile** (Claude's mistake)
2. ❌ **Don't hide tool execution** (transparency is now expected)
3. ❌ **Don't just scale iPhone UI for iPad** (Perplexity shows the right way)
4. ❌ **Don't require multiple taps to reach conversations** (flatten navigation)
5. ❌ **Don't mix code artifacts into chat bubbles** (use separate panels like Claude Artifacts)

---

## Sources Summary

### ChatGPT
- [Comparing Conversational AI Tool User Interfaces 2025](https://intuitionlabs.ai/articles/conversational-ai-ui-comparison-2025)
- [ChatGPT Sidebar Redesign Guide](https://www.ai-toolbox.co/chatgpt-management-and-productivity/chatgpt-sidebar-redesign-guide)
- [Projects in ChatGPT Help Center](https://help.openai.com/en/articles/10169521-projects-in-chatgpt)
- [Updating Your Visual Experience](https://help.openai.com/en/articles/11958281-updating-your-visual-experience-on-chatgpt)
- [Introducing Group Chats in ChatGPT](https://openai.com/index/group-chats-in-chatgpt/)

### Claude
- [Using Claude with iOS Apps](https://support.claude.com/en/articles/11869619-using-claude-with-ios-apps)
- [Claude Pro Mobile App Features Guide](https://aionx.co/claude-ai-reviews/claude-pro-mobile-app-features/)
- [Use Artifacts Help Center](https://support.claude.com/en/articles/9487310-what-are-artifacts-and-how-do-i-use-them)
- [Claude CoWork Ultimate Guide 2026](https://o-mega.ai/articles/claude-cowork-the-ultimate-autonomous-desktop-guide-2026)

### Cursor
- [Cursor Features](https://cursor.com/features)
- [Cursor Changelog 2026](https://blog.promptlayer.com/cursor-changelog-whats-coming-next-in-2026/)
- [Cursor AI vs GitHub Copilot 2026](https://dev.to/thebitforge/cursor-ai-vs-github-copilot-which-2026-code-editor-wins-your-workflow-1019)

### Windsurf (Codeium)
- [Windsurf Review 2026](https://vibecoding.app/blog/windsurf-review)
- [Windsurf Editor](https://codeium.com/windsurf)

### GitHub Copilot
- [GitHub Copilot Chat in GitHub Mobile](https://github.blog/news-insights/product-news/github-copilot-chat-in-github-mobile/)
- [Showing Tool Calls and Improvements](https://github.blog/changelog/2026-02-04-showing-tool-calls-and-other-improvements-to-copilot-chat-on-the-web/)
- [GitHub Copilot in VS Code v1.109](https://github.blog/changelog/2026-02-04-github-copilot-in-visual-studio-code-v1-109-january-release/)
- [Asking GitHub Copilot Questions in IDE](https://docs.github.com/copilot/using-github-copilot/asking-github-copilot-questions-in-your-ide)

### Replit
- [Replit Launches AI Mobile App Builder](https://www.cnbc.com/2026/01/15/ai-startup-replit-launches-feature-to-vibe-code-mobile-apps.html)
- [Replit Agent 3 2026](https://leaveit2ai.com/ai-tools/code-development/replit-agent-v3)
- [Replit Docs - Agent](https://docs.replit.com/replitai/agent)

### Perplexity
- [Perplexity's Revamped iPad App](https://9to5mac.com/2025/12/16/perplexitys-revamped-ipad-app-doubles-down-on-research-tools-and-a-more-native-experience/)
- [Perplexity AI 2026 Complete Guide](https://notiongraffiti.com/perplexity-ai-guide-2026/)

### v0 by Vercel
- [v0 by Vercel](https://v0.dev/)
- [v0 Review 2026](https://leaveit2ai.com/ai-tools/code-development/v0)
- [Maximizing Outputs with v0](https://vercel.com/blog/maximizing-outputs-with-v0-from-ui-generation-to-code-creation)

### Bolt.new
- [Bolt AI Builder](https://bolt.new/)
- [Bolt.new Review 2025](https://www.designmonks.co/case-study/bolt-ai-app-builder-case-study)
- [GitHub - stackblitz/bolt.new](https://github.com/stackblitz/bolt.new)

### Design Patterns
- [Mobile Navigation UX Best Practices 2026](https://www.designstudiouiux.com/blog/mobile-navigation-ux/)
- [9 Mobile App Design Trends for 2026](https://uxpilot.ai/blogs/mobile-app-design-trends)
- [Modern iOS Navigation Patterns](https://frankrausch.com/ios-navigation/)
- [iPad Design Trends 2025](https://asoleap.com/ipad/development/monetization/discover-ipad-design-trends-modern-ui-patterns-2025)
- [Agentic Knowledge Graphs with A2UI](https://medium.com/@visrow/agentic-knowledge-graphs-with-a2ui-why-ai-reasoning-looks-different-in-2026-8e51f3d26cec)

### Session Management Best Practices
- [Claude Code Session Management](https://stevekinney.com/courses/ai-development/claude-code-session-management)
- [My LLM Coding Workflow 2026](https://addyosmani.com/blog/ai-coding-workflow/)
- [Manage Chat Sessions in VS Code](https://code.visualstudio.com/docs/copilot/chat/chat-sessions)

---

**End of Competitive Analysis**
**Next Steps:** Use these findings to inform ILS iOS app redesign specifications.
