---
name: ils-ios-conventions
description: Development conventions and patterns for ils-ios. Swift project with freeform commits.
---

# Ils Ios Conventions

> Generated from [krzemienski/ils-ios](https://github.com/krzemienski/ils-ios) on 2026-03-22

## Overview

This skill teaches Claude the development patterns and conventions used in ils-ios.

## Tech Stack

- **Primary Language**: Swift
- **Architecture**: hybrid module organization
- **Test Location**: separate

## When to Use This Skill

Activate this skill when:
- Making changes to this repository
- Adding new features following established patterns
- Writing tests that match project conventions
- Creating commits with proper message format

## Commit Conventions

Follow these commit message conventions based on 500 analyzed commits.

### Commit Style: Free-form Messages

### Prefixes Used

- `fix`

### Message Guidelines

- Average message length: ~82 characters
- Keep first line concise and descriptive
- Use imperative mood ("Add feature" not "Added feature")


*Commit message example*

```text
fix: eliminate 11 HIG font size violations (size: 10 → theme.fontCaption)
```

*Commit message example*

```text
docs: complete DDD diagrams bootstrap with full audit findings
```

*Commit message example*

```text
merge: Resolve conflicts with master
```

*Commit message example*

```text
chore: update Package.resolved after merge
```

*Commit message example*

```text
feat: merge workflow automation + smart paste from branches 240/246
```

*Commit message example*

```text
fix: exempt localhost connections from API key authentication
```

*Commit message example*

```text
fix: handle missing tables gracefully in AddExtendedDatabaseIndexes migration
```

*Commit message example*

```text
fix: resolve backend build errors from approval policy cherry-picks
```

## Architecture

### Project Structure: Single Package

This project uses **hybrid** module organization.

### Configuration Files

- `.github/workflows/backend-build.yml`
- `.github/workflows/build.yml`
- `.github/workflows/docker.yml`
- `.github/workflows/ios-build.yml`
- `.github/workflows/macos-build.yml`
- `.github/workflows/performance-regression.yml`
- `.github/workflows/release-backend.yml`
- `.github/workflows/test.yml`
- `.github/workflows/testflight.yml`
- `.github/workflows/ui-tests-scheduled.yml`
- `Dockerfile`
- `docker-compose.yml`

### Guidelines

- This project uses a hybrid organization
- Follow existing patterns when adding new code

## Code Style

### Language: Swift

### Naming Conventions

| Element | Convention |
|---------|------------|
| Files | PascalCase |
| Functions | camelCase |
| Classes | PascalCase |
| Constants | SCREAMING_SNAKE_CASE |

### Import Style: Relative Imports

### Export Style: Named Exports


*Preferred import style*

```typescript
// Use relative imports
import { Button } from '../components/Button'
import { useAuth } from './hooks/useAuth'
```

*Preferred export style*

```typescript
// Use named exports
export function calculateTotal() { ... }
export const TAX_RATE = 0.1
export interface Order { ... }
```

## Common Workflows

These workflows were detected from analyzing commit patterns.

### Feature Development

Standard feature implementation workflow

**Frequency**: ~19 times per month

**Steps**:
1. Add feature implementation
2. Add tests for feature
3. Update documentation

**Files typically involved**:
- `ilsapp/ilsapp/theme/components/*`
- `**/*.test.*`
- `**/api/**`

**Example commit sequence**:
```
auto-claude: subtask-1-1 - Add accessibility attributes to ChatView and ChatMessageList
auto-claude: subtask-1-2 - Add accessibility attributes to MessageView.swift
auto-claude: subtask-1-3 - Add accessibility attributes to ChatInputBar.swift
```

### Add Accessibility Attributes To Views

Adds accessibility identifiers, labels, grouping, and traits to SwiftUI view files to improve VoiceOver and UI testing support.

**Frequency**: ~3 times per month

**Steps**:
1. Identify a SwiftUI view lacking accessibility attributes.
2. Add accessibilityIdentifier, accessibilityLabel, accessibilityHint, and/or accessibilityElement modifiers to relevant UI elements.
3. Group related controls for VoiceOver using accessibilityElement(children: .combine/.contain).
4. Commit changes with a message referencing the specific view and attributes added.

**Files typically involved**:
- `ILSApp/ILSApp/Views/Chat/ChatInputBar.swift`
- `ILSApp/ILSApp/Views/Chat/ChatMessageList.swift`
- `ILSApp/ILSApp/Views/Chat/MessageView.swift`
- `ILSApp/ILSApp/Views/Root/SidebarRootView.swift`
- `ILSApp/ILSApp/Views/Root/SidebarView.swift`
- `ILSApp/ILSApp/Views/Settings/SettingsView.swift`

**Example commit sequence**:
```
Identify a SwiftUI view lacking accessibility attributes.
Add accessibilityIdentifier, accessibilityLabel, accessibilityHint, and/or accessibilityElement modifiers to relevant UI elements.
Group related controls for VoiceOver using accessibilityElement(children: .combine/.contain).
Commit changes with a message referencing the specific view and attributes added.
```

### Implement Responsive Layout For Ipad Multitasking

Adapts SwiftUI views to support iPad multitasking widths using adaptive layout utilities and environment values.

**Frequency**: ~2 times per month

**Steps**:
1. Create or update a utility (e.g., AdaptiveLayout.swift) for layout environment keys and helpers.
2. Update target view(s) to read layoutSizeClass or windowWidth from the environment.
3. Replace fixed layouts (e.g., HStack, fixed grid columns) with adaptive layouts (e.g., AnyLayout, adaptive LazyVGrid).
4. Apply .adaptiveLayout() modifier to root views as needed.
5. Test across different iPad multitasking modes.

**Files typically involved**:
- `ILSApp/ILSApp/Utils/AdaptiveLayout.swift`
- `ILSApp/ILSApp/Views/Home/HomeView.swift`
- `ILSApp/ILSApp/Views/Root/SidebarRootView.swift`
- `ILSApp/ILSApp/Views/Chat/ChatInputBar.swift`
- `ILSApp/ILSApp/Views/Chat/ChatMessageList.swift`
- `ILSApp/ILSApp/Views/Dashboard/DashboardGridView.swift`
- `ILSApp/ILSApp/Views/Browser/BrowserView.swift`
- `ILSApp/ILSApp/Views/Settings/SettingsView.swift`
- `ILSApp/ILSApp/Views/System/SystemMonitorView.swift`

**Example commit sequence**:
```
Create or update a utility (e.g., AdaptiveLayout.swift) for layout environment keys and helpers.
Update target view(s) to read layoutSizeClass or windowWidth from the environment.
Replace fixed layouts (e.g., HStack, fixed grid columns) with adaptive layouts (e.g., AnyLayout, adaptive LazyVGrid).
Apply .adaptiveLayout() modifier to root views as needed.
Test across different iPad multitasking modes.
```

### Add Pointer Hover And Hoverstate Support

Adds pointer hover and custom hover state feedback to interactive SwiftUI elements for iPad and Mac Catalyst.

**Frequency**: ~2 times per month

**Steps**:
1. Create or update ViewModifiers (e.g., PointerHoverModifier, HoverStateModifier) and associated extensions.
2. Apply .pointerHover() and/or .hoverState() to interactive elements in target views.
3. Ensure only one hover effect is applied per element to avoid conflicts.
4. Test on iPad (trackpad/mouse) and Mac Catalyst.

**Files typically involved**:
- `ILSApp/ILSApp/Theme/Components/PointerHoverModifier.swift`
- `ILSApp/ILSApp/Views/Root/SidebarSessionRow.swift`
- `ILSApp/ILSApp/Views/Root/SidebarView.swift`
- `ILSApp/ILSApp/Views/Home/HomeView.swift`
- `ILSApp/ILSApp/Theme/Components/AccentButton.swift`
- `ILSApp/ILSApp/Theme/GlassCard.swift`
- `ILSApp/ILSApp/Views/Chat/ChatInputBar.swift`
- `ILSApp/ILSApp/Views/Chat/CodeBlockView.swift`
- `ILSApp/ILSApp/Views/Chat/MessageView.swift`
- `ILSApp/ILSApp/Views/Chat/AssistantCard.swift`
- `ILSApp/ILSApp/Views/Chat/UserMessageCard.swift`
- `ILSApp/ILSApp/Views/Dashboard/WidgetContainerView.swift`

**Example commit sequence**:
```
Create or update ViewModifiers (e.g., PointerHoverModifier, HoverStateModifier) and associated extensions.
Apply .pointerHover() and/or .hoverState() to interactive elements in target views.
Ensure only one hover effect is applied per element to avoid conflicts.
Test on iPad (trackpad/mouse) and Mac Catalyst.
```

### Enhance Session Export Pipeline

Adds or improves session export features, including new formats, range selection, progress indicators, and backend support.

**Frequency**: ~2 times per month

**Steps**:
1. Update backend export endpoints and DTOs to support new fields (e.g., toolCalls, durationSeconds, totalTokens).
2. Update or create export UI components (e.g., SessionExportPickerSheet, MacSessionExportSheet) for new features like format picker, range selection, or progress.
3. Update export service logic (SessionExportService) to handle new formats, range slicing, and progress reporting.
4. Wire range/format parameters through ViewModels and export UI.
5. Test end-to-end export flows on both iOS and macOS.

**Files typically involved**:
- `Sources/ILSBackend/Controllers/SessionsController.swift`
- `Sources/ILSShared/DTOs/Requests.swift`
- `ILSApp/ILSApp/Services/SessionExportService.swift`
- `ILSApp/ILSApp/ViewModels/SessionInfoViewModel.swift`
- `ILSApp/ILSApp/Views/Sessions/SessionExportPickerSheet.swift`
- `ILSApp/ILSMacApp/Views/MacSessionExportSheet.swift`
- `ILSApp/ILSMacApp/Views/MacChatView.swift`

**Example commit sequence**:
```
Update backend export endpoints and DTOs to support new fields (e.g., toolCalls, durationSeconds, totalTokens).
Update or create export UI components (e.g., SessionExportPickerSheet, MacSessionExportSheet) for new features like format picker, range selection, or progress.
Update export service logic (SessionExportService) to handle new formats, range slicing, and progress reporting.
Wire range/format parameters through ViewModels and export UI.
Test end-to-end export flows on both iOS and macOS.
```

### Refactor Backend Route Auth Levels

Moves or reorganizes backend route/controller registration to enforce correct authorization levels (read, write, admin).

**Frequency**: ~2 times per month

**Steps**:
1. Identify controllers or endpoints with incorrect or missing authorization levels.
2. Move controller registration between readRoutes, writeRoutes, and adminRoutes in routes.swift.
3. Update middleware or route registration as needed to match new auth requirements.
4. Test with different token scopes to verify access control.

**Files typically involved**:
- `Sources/ILSBackend/App/routes.swift`

**Example commit sequence**:
```
Identify controllers or endpoints with incorrect or missing authorization levels.
Move controller registration between readRoutes, writeRoutes, and adminRoutes in routes.swift.
Update middleware or route registration as needed to match new auth requirements.
Test with different token scopes to verify access control.
```

### Add Or Update Backend Authentication Flows

Implements or improves backend authentication, including API key rotation, scoped tokens, and E2E auth test scripts.

**Frequency**: ~2 times per month

**Steps**:
1. Add or update controllers (e.g., AuthController.swift) for authentication endpoints.
2. Update middleware and backend configuration to use new storage/services for token validation.
3. Enhance pairing, QR, or Bonjour discovery to support new auth fields.
4. Add or update E2E test scripts for authentication scenarios.
5. Test all flows (key generation, rotation, route access, pairing, etc.).

**Files typically involved**:
- `Sources/ILSBackend/App/routes.swift`
- `Sources/ILSBackend/Controllers/AuthController.swift`
- `Sources/ILSBackend/App/configure.swift`
- `Sources/ILSBackend/Services/BonjourPublisherService.swift`
- `Sources/ILSBackend/Services/PairingService.swift`
- `Sources/ILSShared/DTOs/PairingDTOs.swift`
- `scripts/test_auth_e2e.sh`

**Example commit sequence**:
```
Add or update controllers (e.g., AuthController.swift) for authentication endpoints.
Update middleware and backend configuration to use new storage/services for token validation.
Enhance pairing, QR, or Bonjour discovery to support new auth fields.
Add or update E2E test scripts for authentication scenarios.
Test all flows (key generation, rotation, route access, pairing, etc.).
```


## Best Practices

Based on analysis of the codebase, follow these practices:

### Do

- Use PascalCase for file names
- Prefer named exports

### Don't

- Don't deviate from established patterns without discussion

---

*This skill was auto-generated by [ECC Tools](https://ecc.tools). Review and customize as needed for your team.*
