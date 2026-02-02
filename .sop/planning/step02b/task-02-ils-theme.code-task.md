# Task: Create ILSTheme.swift

## Description
Create a centralized theme configuration file that defines colors, typography, spacing, and common view modifiers for consistent styling throughout the ILS app.

## Background
A theme struct provides type-safe access to design tokens and promotes consistency. SwiftUI view modifiers encapsulate common styling patterns for reuse.

## Reference Documentation
**Required:**
- Design: .sop/planning/design/detailed-design.md

**Note:** You MUST read the detailed design document before beginning implementation.

## Technical Requirements
1. Create ILSTheme struct with static color properties
2. Reference colors from asset catalog using Color("name")
3. Define typography scale (title, headline, body, caption, code)
4. Define spacing scale (xs: 4, sm: 8, md: 16, lg: 24, xl: 32)
5. Define corner radius scale (sm: 8, md: 12, lg: 16)
6. Create custom ViewModifiers for common patterns
7. Create card style modifier with background, corner radius, shadow
8. Create primary button style with orange background
9. Create text field style for dark theme inputs

## Dependencies
- Color assets from Task 2B.1

## Implementation Approach
1. Create ILSApp/ILSApp/Theme/ILSTheme.swift
2. Define ILSTheme struct with Color static properties
3. Add Typography enum or struct with Font definitions
4. Add Spacing and CornerRadius enums
5. Create CardModifier: ViewModifier with dark background
6. Create PrimaryButtonStyle: ButtonStyle with orange accent
7. Create ILSTextFieldStyle: TextFieldStyle for inputs
8. Add View extensions for easy modifier access (.ilsCard(), etc.)
9. Verify compilation and preview rendering

## Acceptance Criteria

1. **Color Access**
   - Given ILSTheme.background
   - When used in a View
   - Then correct color from asset catalog is applied

2. **Typography Scale**
   - Given ILSTheme.Typography
   - When accessing .title, .body, .code
   - Then appropriate Font values are returned

3. **Card Modifier**
   - Given a View with .ilsCard() modifier
   - When rendered
   - Then dark background, corner radius, and subtle shadow are applied

4. **Button Style**
   - Given a Button with ILSTheme button style
   - When rendered
   - Then orange background with white text is displayed

5. **Compilation Success**
   - Given the ILSTheme file
   - When building the project
   - Then build succeeds with zero errors

6. **Preview Renders**
   - Given views using ILSTheme
   - When viewing in Xcode Preview
   - Then dark theme styling is visible

## Metadata
- **Complexity**: Medium
- **Labels**: iOS, Design System, Theme, SwiftUI, ViewModifiers
- **Required Skills**: SwiftUI, ViewModifier, ButtonStyle, Design systems
