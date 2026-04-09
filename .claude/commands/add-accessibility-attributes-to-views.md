---
name: add-accessibility-attributes-to-views
description: Workflow command scaffold for add-accessibility-attributes-to-views in ils-ios.
allowed_tools: ["Bash", "Read", "Write", "Grep", "Glob"]
---

# /add-accessibility-attributes-to-views

Use this workflow when working on **add-accessibility-attributes-to-views** in `ils-ios`.

## Goal

Adds accessibility identifiers, labels, grouping, and traits to SwiftUI view files to improve VoiceOver and UI testing support.

## Common Files

- `ILSApp/ILSApp/Views/Chat/ChatInputBar.swift`
- `ILSApp/ILSApp/Views/Chat/ChatMessageList.swift`
- `ILSApp/ILSApp/Views/Chat/MessageView.swift`
- `ILSApp/ILSApp/Views/Root/SidebarRootView.swift`
- `ILSApp/ILSApp/Views/Root/SidebarView.swift`
- `ILSApp/ILSApp/Views/Settings/SettingsView.swift`

## Suggested Sequence

1. Understand the current state and failure mode before editing.
2. Make the smallest coherent change that satisfies the workflow goal.
3. Run the most relevant verification for touched files.
4. Summarize what changed and what still needs review.

## Typical Commit Signals

- Identify a SwiftUI view lacking accessibility attributes.
- Add accessibilityIdentifier, accessibilityLabel, accessibilityHint, and/or accessibilityElement modifiers to relevant UI elements.
- Group related controls for VoiceOver using accessibilityElement(children: .combine/.contain).
- Commit changes with a message referencing the specific view and attributes added.

## Notes

- Treat this as a scaffold, not a hard-coded script.
- Update the command if the workflow evolves materially.