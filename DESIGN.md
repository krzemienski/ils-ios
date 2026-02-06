# Design System: ILS iOS App

## Stitch Projects

| Project | ID | Purpose |
|---------|-----|---------|
| Original | `5534378398573236609` | Initial design explorations |
| **Redesign 2026** | **`6714718863820708466`** | Complete 15-screen redesign (current) |

Open in [Stitch](https://stitch.withgoogle.com) and search "ILS iOS App Redesign 2026"

**Design Theme (auto-detected by Stitch):** Dark mode, custom color #FF6600, Inter font, Round-12 corners, Saturation 3

## 1. Visual Theme & Atmosphere
A sleek, developer-focused mobile app with a flat black dark theme. The atmosphere is sophisticated, technical, and utilitarian — like a premium developer tool. The UI feels dense but organized, with careful use of negative space. No gradients, no decorative elements — pure functionality elevated by precise spacing and bold accent hits. Think "Xcode meets Linear meets Raycast" — tools built by developers, for developers.

## 2. Color Palette & Roles
- **Deep Black (#000000)** — Primary background, the dominant canvas color
- **Charcoal Surface (#1C1C1E)** — Card backgrounds, secondary surfaces, input fields
- **Dark Gray Elevation (#2C2C2E)** — Tertiary surfaces, hover states, code blocks
- **Hot Orange (#FF6600)** — Primary accent for buttons, links, active states, FAB buttons, and interactive highlights
- **Ember Orange Glow (rgba(255,102,0,0.15))** — User message bubbles, subtle accent backgrounds
- **Pure White (#FFFFFF)** — Primary text, headings, high-emphasis content
- **Silver Gray (#8E8E93)** — Secondary text, labels, metadata
- **Ash Gray (#48484A)** — Tertiary text, timestamps, disabled states
- **Signal Green (#34C759)** — Success states, healthy indicators, active badges
- **Alert Red (#FF3B30)** — Error states, destructive actions, stop button
- **Caution Orange (#FF9500)** — Warning states, reconnecting indicators
- **Ocean Blue (#007AFF)** — Info states, links, informational badges

## 3. Typography Rules
- **System Font (SF Pro)** — Used throughout for native iOS feel
- **Headings:** Bold weight, system title size — commands authority without shouting
- **Body Text:** Regular weight, system body size — comfortable reading
- **Captions/Metadata:** Regular weight, system caption size — recedes visually
- **Code:** Monospaced (SF Mono) — for file paths, commands, tool names, JSON content
- **Letter spacing:** Default system spacing — tight, efficient, information-dense

## 4. Component Stylings
* **Buttons:** Rounded corners (8px radius), Hot Orange (#FF6600) background with white text for primary. Secondary buttons use charcoal background with orange text. FAB (floating action button) is circular, orange, with white icon and subtle shadow.
* **Cards/Containers:** Charcoal Surface (#1C1C1E) background, subtly rounded (12px radius), no visible border, no shadow on dark theme — elevation communicated through color only.
* **Inputs/Forms:** Dark Gray (#2C2C2E) background, no visible border, rounded (8px), placeholder text in Ash Gray (#48484A).
* **Status Badges:** Small pill-shaped (4px radius), colored background matching status (green/red/blue/orange), white text, caption-sized font.
* **List Rows:** Full-width on Charcoal Surface, 4px vertical padding, subtle separator lines in very dark gray.
* **Navigation Bar:** Flat black background, large title in white, orange accent for action buttons.
* **Tab Bar/Sidebar:** Flat black, selected item highlighted with orange accent, unselected in Silver Gray.
* **Message Bubbles:** User messages in Ember Orange Glow (orange-tinted), assistant messages in Charcoal Surface.
* **Tool Call Blocks:** Expandable, Dark Gray background, orange wrench icon, chevron toggle.
* **Tag Pills:** Orange at 15% opacity background with orange text, small corner radius, horizontal scroll for overflow.
* **Skeleton Loading:** `.redacted(reason: .placeholder)` pattern matching actual content layout.

## 5. Layout Principles
- **Spacing scale:** 4px / 8px / 16px / 24px / 32px — consistent rhythm
- **Full-width list items** with generous internal padding (16px)
- **Stats grid:** 2-column grid of equal cards with 16px gap
- **Content-first density:** Information-rich rows showing name, metadata, status in compact layout
- **Safe area respected** with no edge-to-edge content bleeds
- **Pull-to-refresh** on all list views
- **Bottom safe area** preserved for FAB buttons and input bars

## 6. Screen Inventory (15 Screens in Stitch Project)

### Primary Screens
| # | Screen | Description | Key Components |
|---|--------|-------------|----------------|
| 1 | **Dashboard** | Stats overview + recent activity | 2x2 stat grid (Projects 371, Sessions 3, Skills 1527, MCP 20), activity feed, skeleton loading |
| 2 | **Sessions List** | Chat session browser | Session cards with status badges, FAB, pulsing active indicator, swipe-delete |
| 3 | **Chat View** | AI conversation interface | Message bubbles, streaming status banner, tool calls, typing indicator, input bar |
| 4 | **Projects List** | Codebase project browser | Path in monospace, model badges, session counts, 371 projects |
| 5 | **Skills List** | Slash-command browser | Searchable, tag pills, active checkmarks, 1527 skills |

### Secondary Screens
| # | Screen | Description | Key Components |
|---|--------|-------------|----------------|
| 6 | **MCP Servers** | Server management | Health status dots, command display in monospace, env var badges |
| 7 | **Plugins** | Plugin manager | Enable/disable toggles, command pills, marketplace button |
| 8 | **Settings** | App configuration | 7 sections: connection, general, API key, permissions, advanced, statistics, about |

### Modal/Sheet Screens
| # | Screen | Description | Key Components |
|---|--------|-------------|----------------|
| 9 | **New Session** | Create session form | Model segmented control, project picker, permission modes |
| 10 | **Session Info** | Session details sheet | LabeledContent sections, cost display, Claude session ID |
| 11 | **Command Palette** | Slash command picker | Searchable list: built-in commands, skills, model switching |
| 12 | **Sidebar** | Navigation menu | 7 nav items, connection status, active project display |
| 13 | **Project Detail** | Project edit/view | Edit mode toggle, statistics, delete action |
| 14 | **Marketplace** | Plugin discovery | Organized by source (npm, community), install buttons |
| 15 | **Skill Detail** | Skill content viewer | Markdown content block, tags, copy action, toast notification |

## 7. Navigation Architecture

```
App Launch
  +-- Dashboard (default tab)
  +-- Sessions List
  |     +-- Chat View
  |     |     +-- Command Palette (sheet)
  |     |     +-- Session Info (sheet)
  |     |     +-- Fork Session (alert)
  |     +-- New Session (sheet)
  +-- Projects List
  |     +-- Project Detail (sheet)
  |     +-- New Project (sheet)
  +-- Skills List
  |     +-- Skill Detail (push)
  |     +-- Skill Editor (sheet)
  +-- MCP Servers
  |     +-- Server Detail (push)
  |     +-- New Server (sheet)
  +-- Plugins
  |     +-- Marketplace (sheet)
  +-- Settings
  |     +-- User Config Editor (push)
  |     +-- Project Config Editor (push)
  +-- Sidebar (sheet from toolbar)
```

## 8. Design Decisions

1. **Pure Black Background (#000000):** Maximizes OLED battery savings and creates premium dark mode feel
2. **Hot Orange Accent (#FF6600):** Distinctive, energetic brand color that stands out on dark backgrounds
3. **System Dynamic Type:** All fonts use SF Pro system styles for accessibility
4. **Reduce Motion Support:** All animations check `UIAccessibility.isReduceMotionEnabled`
5. **Pull-to-Refresh:** Every list screen supports refreshable for data freshness
6. **Sheet Presentation:** Secondary screens use `.sheet` for modal presentation
7. **Haptic Feedback:** Send button and copy actions trigger impact/notification haptics
8. **Text Selection:** All code blocks and message content support `.textSelection(.enabled)`
9. **Skeleton Loading:** Dashboard uses placeholder redaction matching real layout
10. **Accessibility IDs:** Every interactive element has `.accessibilityIdentifier` for automation

## 9. Stitch Generation Reference

When generating new screens with Stitch, include this design block:

**DESIGN SYSTEM (REQUIRED):**
- Platform: Mobile (iOS), iPhone
- Theme: Dark, flat black, developer-focused, utilitarian
- Background: Deep Black (#000000)
- Surface: Charcoal (#1C1C1E) for cards and secondary surfaces
- Tertiary Surface: Dark Gray (#2C2C2E) for code blocks and elevated elements
- Primary Accent: Hot Orange (#FF6600) for all interactive elements
- Text Primary: Pure White (#FFFFFF)
- Text Secondary: Silver Gray (#8E8E93)
- Text Tertiary: Ash Gray (#48484A)
- Success: Signal Green (#34C759)
- Error: Alert Red (#FF3B30)
- Buttons: 8px rounded corners, orange primary, charcoal secondary
- Cards: 12px rounded corners, charcoal background, no border
- Font: System (SF Pro), monospaced for code
- Spacing: 4/8/16/24/32px scale
- Style: No gradients, no decorative elements, flat surfaces, color-only elevation
