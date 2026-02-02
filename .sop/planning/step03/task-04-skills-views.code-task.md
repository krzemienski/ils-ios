# Task: Create SkillsListView and SkillDetailView

## Description
Create the skills management views including a list of installed skills and a detail view for viewing/editing individual skills. Support SKILL.md content display and editing.

## Background
Skills are Claude Code's extension mechanism defined in SKILL.md files. The app allows browsing installed skills, viewing their content, and basic editing operations.

## Reference Documentation
**Required:**
- Design: .sop/planning/design/detailed-design.md

**Note:** You MUST read the detailed design document before beginning implementation.

## Technical Requirements
1. Create SkillsListView with list of installed skills
2. Add search/filter functionality
3. Show skill status badges (active/inactive)
4. Add toolbar button to create new skill
5. Create SkillDetailView showing skill information
6. Display skill name, description, and location
7. Show SKILL.md content preview (syntax highlighted if possible)
8. Add Edit SKILL.md button for editing
9. Add Uninstall button (red, with confirmation)
10. Navigation from list to detail view

## Dependencies
- ILSShared Skill model
- ILSTheme styling
- APIClient for skill operations

## Implementation Approach
1. Create ILSApp/ILSApp/Views/Skills/SkillsListView.swift
2. Create SkillsViewModel with @Published skills array
3. Implement search filtering with searchable modifier
4. Create skill row component with name, description, status
5. Create ILSApp/ILSApp/Views/Skills/SkillDetailView.swift
6. Display skill metadata in styled sections
7. Add code preview for SKILL.md content (use monospace font)
8. Implement edit navigation
9. Implement uninstall with confirmation alert
10. Verify compilation and navigation

## Acceptance Criteria

1. **Skills List**
   - Given installed skills
   - When SkillsListView renders
   - Then skills are listed with name, description, status

2. **Search Functionality**
   - Given the skills list
   - When typing in search field
   - Then list filters to matching skills

3. **Skill Detail Display**
   - Given a selected skill
   - When SkillDetailView renders
   - Then name, description, location, and content preview are shown

4. **SKILL.md Preview**
   - Given skill content
   - When viewing detail
   - Then markdown/yaml content is displayed in monospace font

5. **Uninstall Confirmation**
   - Given the uninstall button
   - When tapped
   - Then confirmation alert appears before deletion

6. **Navigation Flow**
   - Given the skills list
   - When tapping a skill
   - Then detail view is pushed onto navigation stack

7. **Compilation Success**
   - Given both views
   - When building the project
   - Then build succeeds with zero errors

## Metadata
- **Complexity**: Medium
- **Labels**: iOS, SwiftUI, Views, Skills, List, Detail
- **Required Skills**: SwiftUI navigation, List, searchable, MVVM
