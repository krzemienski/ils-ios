# Task: Create Color Assets

## Description
Create the color asset catalog for the ILS iOS app. Define the dark theme color palette with orange accent colors that align with the Claude Code aesthetic.

## Background
ILS uses a dark theme inspired by terminal aesthetics with orange accents. Colors are defined in the asset catalog for proper dark/light mode support and easy reference throughout the app.

## Reference Documentation
**Required:**
- Design: .sop/planning/design/detailed-design.md

**Note:** You MUST read the detailed design document before beginning implementation.

## Technical Requirements
1. Create color set for primary background (#000000)
2. Create color set for secondary background (#1C1C1E)
3. Create color set for tertiary background (#2C2C2E)
4. Create color set for primary text (#FFFFFF)
5. Create color set for secondary text (#8E8E93)
6. Create color set for accent/orange (#FF6B00 or similar)
7. Create color set for success (#34C759)
8. Create color set for error (#FF3B30)
9. Create color set for warning (#FF9500)
10. Organize in Assets.xcassets with descriptive names

## Dependencies
- Xcode project from Phase 0

## Implementation Approach
1. Open ILSApp.xcassets in Xcode
2. Create new Color Set for each color
3. Configure Appearances as "None" (dark theme only for MVP)
4. Set Universal color values using hex
5. Name colors with ILS prefix (e.g., ILSBackground, ILSAccent)
6. Verify colors display correctly in preview

## Acceptance Criteria

1. **Background Colors**
   - Given the asset catalog
   - When inspecting color sets
   - Then ILSBackground (#000000), ILSBackgroundSecondary, ILSBackgroundTertiary exist

2. **Text Colors**
   - Given the asset catalog
   - When inspecting color sets
   - Then ILSTextPrimary (#FFFFFF) and ILSTextSecondary exist

3. **Accent Color**
   - Given the asset catalog
   - When inspecting color sets
   - Then ILSAccent (orange) exists

4. **Status Colors**
   - Given the asset catalog
   - When inspecting color sets
   - Then ILSSuccess, ILSError, ILSWarning exist with appropriate colors

5. **Build Success**
   - Given the configured asset catalog
   - When building the project
   - Then build succeeds and colors are accessible via Color("name")

## Metadata
- **Complexity**: Low
- **Labels**: iOS, Design System, Colors, Assets, Theme
- **Required Skills**: Xcode asset catalog, Color design
