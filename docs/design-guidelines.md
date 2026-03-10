# ILS Design System & Guidelines

**Version:** 1.1.1 | **Last Updated:** 2026-03-10

---

## Overview

ILS uses a **concrete theme system** (ThemeSnapshot) with 13 built-in themes and a custom theme editor. The design emphasizes clarity, accessibility, and dark mode support.

**Key Principles:**
- Concrete value types (no existential containers)
- System-adaptive colors (light/dark)
- Dynamic Type support (accessibility)
- Responsive layout (iPad, macOS multi-window)

---

## Color System

### Core Palette

**Backgrounds:**
```swift
struct ThemeSnapshot {
    let bgPrimary: Color     // Main app background
    let bgSecondary: Color   // Cards, panels
    let bgTertiary: Color    // Subtle sections
    let bgSidebar: Color     // Sidebar background
}
```

**Text:**
```swift
let textPrimary: Color       // Primary text
let textSecondary: Color     // Secondary labels
let textTertiary: Color      // Disabled/hint text
let textOnAccent: Color      // Text on accent backgrounds
```

**Semantic:**
```swift
let accent: Color            // Interactive elements, highlights
let accentSecondary: Color   // Secondary interactive
let accentGradient: LinearGradient  // Gradients (accent → secondary)
let success: Color           // Success states
let warning: Color           // Warnings
let error: Color             // Errors
let info: Color              // Information
```

**Entity Colors** (for data visualization):
```swift
struct EntityColors {
    let session: Color
    let project: Color
    let skill: Color
    let plugin: Color
    let workflow: Color
    let checkpoint: Color
}
```

### Built-In Themes (13 Total)

| Theme | Primary Color | Style | Use Case |
|-------|---------------|-------|----------|
| **ILS Theme** | Hot Orange | System-adaptive | Default, professional |
| **Obsidian** | Deep Blue | Dark first | Code editors, dark rooms |
| **Neon Noir** | Cyan + Purple | Neon accents | Gaming, high contrast |
| **Ember** | Warm Red | Sunset vibes | Creative work |
| **Forest** | Green | Natural tones | Outdoor, calm |
| **Midnight** | Dark Blue | Minimal | Night mode |
| **Aurora** | Purple + Pink | Gradient heavy | Modern, vibrant |
| **Cyberpunk** | Neon + Dark | Extreme contrast | Sci-fi aesthetic |
| **Minimal Light** | Neutral | Light background | Accessibility |
| **High Contrast** | B/W + Red | Maximum contrast | Accessibility |
| **Accessible** | Blue + Yellow | WCAG AAA | Certified accessible |
| **Classic** | Gray + Blue | Traditional | Apple design |
| **Custom** | User-defined | Any | Personal preference |

### Dark Mode Support

```swift
// Automatic adaptation
@Environment(\.colorScheme) var colorScheme

private var effectiveColor: Color {
    switch colorScheme {
    case .light: return theme.bgSecondary
    case .dark: return theme.bgTertiary
    @unknown default: return theme.bgSecondary
    }
}
```

**Rule:** All colors auto-adapt to system dark mode + theme selection.

---

## Typography System

### Font Definitions

```swift
struct ThemeSnapshot {
    // Headings
    let fontTitle: UIFont      // 28pt, bold
    let fontTitle2: UIFont     // 22pt, semibold
    let fontTitle3: UIFont     // 20pt, semibold

    // Body
    let fontBody: UIFont       // 17pt, regular
    let fontBodyBold: UIFont   // 17pt, semibold
    let fontBodyMono: UIFont   // 17pt, monospace

    // Small
    let fontSubheadline: UIFont  // 15pt, regular
    let fontCaption: UIFont      // 12pt, regular
    let fontCaption2: UIFont     // 11pt, regular

    // Code
    let fontCode: UIFont       // Monospace, 13pt
    let fontCodeSmall: UIFont  // Monospace, 11pt
}
```

### Usage Rules

```swift
// Headings
Text("Session Name")
    .font(theme.fontTitle2)
    .foregroundColor(theme.textPrimary)

// Body text
Text("Message content")
    .font(theme.fontBody)
    .foregroundColor(theme.textPrimary)

// Captions
Text("2h ago")
    .font(theme.fontCaption)
    .foregroundColor(theme.textTertiary)

// Code
Text("print('hello')")
    .font(theme.fontCode)
    .foregroundColor(theme.success)
```

### Dynamic Type Support

```swift
// All text automatically scales with user's dynamic type setting
Text("Hello")
    .font(theme.fontBody)
    // Dynamic Type: this scales to user's accessibility setting
    .dynamicTypeSize(.xSmall ... .accessibility3)  // Supported range
```

**Rule:** Never use fixed font sizes. Always use theme font properties.

---

## Spacing System

### Density Levels

Three layout densities control overall spacing:

```swift
enum Density: String, CaseIterable {
    case compact     // Minimal spacing, dense UI
    case normal      // Default spacing
    case spacious    // Generous spacing, less content per screen
}

// Access in views
@Environment(\.density) var density: Density

// Compute spacing
private var itemSpacing: CGFloat {
    switch density {
    case .compact: return 4
    case .normal: return 8
    case .spacious: return 12
    }
}
```

### Spacing Constants

```swift
struct Spacing {
    static let xs: CGFloat = 4        // Micro gaps
    static let sm: CGFloat = 8        // Small gaps
    static let md: CGFloat = 16       // Standard padding
    static let lg: CGFloat = 24       // Large sections
    static let xl: CGFloat = 32       // Extra large gaps
}

// Usage
VStack(spacing: Spacing.md) {
    Text("Title")
    Text("Subtitle")
}
```

### Corner Radius

```swift
struct Radius {
    static let small: CGFloat = 4
    static let medium: CGFloat = 8     // Standard card radius
    static let large: CGFloat = 12
    static let full: CGFloat = .infinity
}

// Usage
RoundedRectangle(cornerRadius: Radius.medium)
    .fill(theme.bgSecondary)
```

---

## Component Library

### Cards

```swift
struct Card<Content: View>: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    let content: Content

    var body: some View {
        content
            .padding(Spacing.md)
            .background(theme.bgSecondary)
            .cornerRadius(Radius.medium)
            .shadow(color: theme.bgTertiary, radius: 2)
    }
}

// Usage
Card {
    VStack(alignment: .leading) {
        Text("Session").font(theme.fontTitle3)
        Text("Description").font(theme.fontCaption)
    }
}
```

### Buttons

```swift
// Primary Button (emphasis)
Button(action: { /* ... */ }) {
    Label("Send", systemImage: "paperplane.fill")
        .font(theme.fontBodyBold)
}
.buttonStyle(.borderedProminent)
.tint(theme.accent)

// Secondary Button (less emphasis)
Button(action: { /* ... */ }) {
    Label("Cancel", systemImage: "xmark")
        .font(theme.fontBody)
}
.buttonStyle(.bordered)
.tint(theme.textSecondary)
```

### Input Fields

```swift
TextField("Search", text: $searchText)
    .textFieldStyle(.roundedBorder)
    .padding(Spacing.sm)
    .background(theme.bgSecondary)
    .cornerRadius(Radius.small)
```

### Lists

```swift
List {
    ForEach(items) { item in
        NavigationLink(destination: Detail(item)) {
            ListItemView(item)
        }
    }
}
.listStyle(.plain)  // Custom styling
.background(theme.bgPrimary)
```

### Modals

```swift
.sheet(isPresented: $showModal) {
    VStack {
        Text("Modal Title").font(theme.fontTitle2)
        // Content
    }
    .padding(Spacing.lg)
    .background(theme.bgPrimary)
}
```

---

## Accessibility Guidelines

### Color Contrast

**WCAG AA Standards:**
- Body text (≥14pt): 4.5:1 contrast ratio
- Large text (≥18pt bold): 3:1 contrast ratio

**Verification:**
```swift
// Check contrast in Xcode Accessibility Inspector
// Settings > Accessibility > Display & Text Size > Increase Contrast
```

### Text Sizing

```swift
// Rule: Use Dynamic Type everywhere
Text("Hello").font(theme.fontBody)
    .dynamicTypeSize(.xSmall ... .accessibility3)
```

**Do NOT:**
```swift
Text("Hello").font(.system(size: 12))  // ❌ Fixed size, no scaling
```

### Accessibility Labels

```swift
Button(action: { /* send message */ }) {
    Image(systemName: "paperplane.fill")
        .accessibilityLabel("Send message")
        .accessibilityHint("Sends the current message to Claude")
}
```

### VoiceOver Support

```swift
Text("Status: Active")
    .accessibilityElement(children: .combine)  // Read as single element

Image(systemImage: "checkmark.circle")
    .accessibilityLabel("Complete")
    .accessibilityHidden(false)  // Ensure VoiceOver reads it
```

---

## Layout Patterns

### Sidebar Navigation (iOS)

```swift
struct SidebarRootView: View {
    @State private var sidebarOpen = false

    var body: some View {
        ZStack {
            TabView {
                // Main content
            }

            if sidebarOpen {
                Sidebar()
                    .transition(.move(edge: .leading))
            }
        }
    }
}
```

### Split View (macOS)

```swift
struct MacRootView: View {
    @State private var selectedSession: Session?

    var body: some View {
        NavigationSplitView {
            SessionsList(selection: $selectedSession)
        } detail: {
            if let session = selectedSession {
                ChatView(session: session)
            }
        }
    }
}
```

### Responsive Layout (iPad)

```swift
struct ResponsiveView: View {
    @Environment(\.horizontalSizeClass) var sizeClass

    var body: some View {
        if sizeClass == .regular {
            // Landscape: side-by-side
            HStack {
                Sidebar()
                Content()
            }
        } else {
            // Portrait: stacked
            VStack {
                Content()
                Sidebar()
            }
        }
    }
}
```

---

## Dark Mode Design

### Color Selection

```swift
// Automatic light/dark support
Color(red: 0.1, green: 0.1, blue: 0.1)  // Works in both modes

// Or use semantic colors
theme.bgPrimary  // Automatically adapts to light/dark
```

### Shadows

```swift
// Reduce shadow prominence in dark mode
let shadowColor: Color = colorScheme == .dark ? theme.bgTertiary : theme.bgSecondary
let shadowOpacity: Double = colorScheme == .dark ? 0.2 : 0.1

RoundedRectangle(cornerRadius: Radius.medium)
    .shadow(color: shadowColor, radius: 4, x: 0, y: 2)
```

### Images & Icons

```swift
// System images auto-adapt to theme
Image(systemName: "sun.max")
    .foregroundColor(theme.accent)
    // Automatically renders correctly in light/dark

// Custom images should have light/dark variants
Image(colorScheme == .dark ? "logo-dark" : "logo-light")
```

---

## Component States

### Disabled State

```swift
Button(action: { /* ... */ }) {
    Text("Send")
}
.disabled(!canSend)
.opacity(canSend ? 1.0 : 0.5)
```

### Loading State

```swift
if isLoading {
    ProgressView()
} else {
    Content()
}
```

### Error State

```swift
if let error = error {
    VStack {
        Image(systemName: "exclamationmark.circle")
            .foregroundColor(theme.error)
        Text(error.localizedDescription)
            .foregroundColor(theme.textPrimary)
    }
}
```

### Empty State

```swift
VStack {
    Image(systemName: "folder.badge.questionmark")
        .font(.system(size: 48))
        .foregroundColor(theme.textTertiary)
    Text("No sessions yet")
        .font(theme.fontTitle3)
    Text("Create a new session to get started")
        .font(theme.fontCaption)
        .foregroundColor(theme.textSecondary)
}
.padding(Spacing.lg)
```

---

## Animation Guidelines

### Transitions

```swift
// Slide transition
content
    .transition(.move(edge: .leading))

// Fade transition
content
    .transition(.opacity)

// Combined
content
    .transition(.move(edge: .trailing).combined(with: .opacity))
```

### Timing

```swift
// Standard (iOS default)
withAnimation(.easeInOut(duration: 0.3)) {
    // State change
}

// Snappy (quick feedback)
withAnimation(.easeOut(duration: 0.15)) {
    // Dismiss modal
}

// Smooth (long transitions)
withAnimation(.easeInOut(duration: 0.6)) {
    // Page transition
}
```

### ScenePhase Pausing

```swift
@Environment(\.scenePhase) var scenePhase

var body: some View {
    VStack {
        AnimatedView()
    }
    .onChange(of: scenePhase) { oldPhase, newPhase in
        if newPhase == .background {
            // Pause animations to save battery
            pauseAnimations()
        } else if newPhase == .active {
            // Resume animations
            resumeAnimations()
        }
    }
}
```

---

## Custom Theme Editor

Users can create custom themes via:

1. **Color Picker** — Select colors for all semantic roles
2. **Font Selection** — Choose font family and sizes
3. **Preview** — Live preview of custom theme
4. **Save & Export** — Save as `.json` or share

**Example Custom Theme:**
```json
{
  "name": "My Custom Theme",
  "colors": {
    "bgPrimary": "#ffffff",
    "bgSecondary": "#f5f5f5",
    "accent": "#ff6b35",
    "textPrimary": "#000000",
    "textSecondary": "#666666"
  },
  "typography": {
    "fontBody": "San Francisco",
    "fontBodySize": 17
  }
}
```

---

## Platform Differences

### iOS Specific

```swift
// Safe area insets (notch, home indicator)
.ignoresSafeArea(edges: .bottom)  // For full-bleed backgrounds

// Haptics
import UIKit
let impact = UIImpactFeedbackGenerator(style: .medium)
impact.impactOccurred()
```

### macOS Specific

```swift
// Menu bar integration
@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

// Touch bar
.touchBar {
    Group {
        Button("Action") { /* ... */ }
    }
}

// Multi-window support
WindowGroup("Chat", for: Session.ID.self) { sessionId in
    ChatView(sessionId: sessionId)
}
```

---

## Design Best Practices

### Do's

- Use theme colors consistently
- Ensure sufficient contrast (4.5:1 body, 3:1 large)
- Scale text with Dynamic Type
- Support light and dark modes
- Test on multiple device sizes
- Use system icons when possible
- Group related content in cards
- Provide clear feedback on interactions
- Use animations sparingly (paused when backgrounded)

### Don'ts

- Hardcode colors (#FFFFFF, UIColor.red)
- Use fixed font sizes (always use theme fonts)
- Ignore dark mode
- Skip accessibility labels
- Animate continuously (drain battery)
- Use more than 3 accent colors per screen
- Clutter with too many options
- Forget padding and alignment

---

## Implementation Checklist

Before shipping any screen:

- [ ] Uses theme colors (bgPrimary, textPrimary, accent, etc.)
- [ ] Uses theme fonts (fontBody, fontTitle, fontCaption, etc.)
- [ ] Supports Dynamic Type (no fixed sizes)
- [ ] Respects density setting (Compact/Normal/Spacious)
- [ ] Dark mode tested (appears in both light and dark)
- [ ] Accessibility labels on interactive elements
- [ ] Contrast verified (4.5:1 body, 3:1 large)
- [ ] Animations paused in background (scenePhase)
- [ ] Responsive layout (iPhone, iPad, macOS)
- [ ] All images support light/dark variants

---

## Reference

- **Color Reference:** `ILSApp/ILSApp/Theme/ThemeSnapshot.swift`
- **Built-In Themes:** `ILSApp/ILSApp/Theme/ILSTheme.swift` + theme variants
- **Theme Editor:** `Views/Themes/ThemeEditorView.swift`
- **Component Examples:** See individual View files (ChatView, SessionsView, etc.)
