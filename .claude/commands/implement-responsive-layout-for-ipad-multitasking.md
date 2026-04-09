---
name: implement-responsive-layout-for-ipad-multitasking
description: Workflow command scaffold for implement-responsive-layout-for-ipad-multitasking in ils-ios.
allowed_tools: ["Bash", "Read", "Write", "Grep", "Glob"]
---

# /implement-responsive-layout-for-ipad-multitasking

Use this workflow when working on **implement-responsive-layout-for-ipad-multitasking** in `ils-ios`.

## Goal

Adapts SwiftUI views to support iPad multitasking widths using adaptive layout utilities and environment values.

## Common Files

- `ILSApp/ILSApp/Utils/AdaptiveLayout.swift`
- `ILSApp/ILSApp/Views/Home/HomeView.swift`
- `ILSApp/ILSApp/Views/Root/SidebarRootView.swift`
- `ILSApp/ILSApp/Views/Chat/ChatInputBar.swift`
- `ILSApp/ILSApp/Views/Chat/ChatMessageList.swift`
- `ILSApp/ILSApp/Views/Dashboard/DashboardGridView.swift`

## Suggested Sequence

1. Understand the current state and failure mode before editing.
2. Make the smallest coherent change that satisfies the workflow goal.
3. Run the most relevant verification for touched files.
4. Summarize what changed and what still needs review.

## Typical Commit Signals

- Create or update a utility (e.g., AdaptiveLayout.swift) for layout environment keys and helpers.
- Update target view(s) to read layoutSizeClass or windowWidth from the environment.
- Replace fixed layouts (e.g., HStack, fixed grid columns) with adaptive layouts (e.g., AnyLayout, adaptive LazyVGrid).
- Apply .adaptiveLayout() modifier to root views as needed.
- Test across different iPad multitasking modes.

## Notes

- Treat this as a scaffold, not a hard-coded script.
- Update the command if the workflow evolves materially.