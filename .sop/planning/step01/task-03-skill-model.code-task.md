# Task: Create Skill Model with YAML Parsing

## Description
Create the Skill model and SkillParser for reading and writing SKILL.md files. Skills use YAML frontmatter for metadata (name, description) followed by markdown instructions.

## Background
Claude Code skills are defined in SKILL.md files with YAML frontmatter. The ILS app needs to parse these files to display skill information and allow editing. The Yams library is used for YAML parsing.

## Reference Documentation
**Required:**
- Design: .sop/planning/design/detailed-design.md

**Additional References:**
- .sop/planning/research/claude-code-features.md (for skill file format)

**Note:** You MUST read the detailed design document before beginning implementation.

## Technical Requirements
1. Create Skill struct with: id, name, description, version, isActive, path, rawContent, source
2. Create SkillSource enum with cases: local, github(repository, stars)
3. Create SkillParser with ParsedSkill result struct
4. Implement parse() method using regex to split frontmatter from content
5. Use Yams library to parse YAML frontmatter
6. Define ParseError enum for error handling (noFrontmatter, invalidYAML, missingRequiredField)
7. Implement generateContent() method for creating SKILL.md content

## Dependencies
- Yams package dependency (already in Package.swift)
- Foundation framework

## Implementation Approach
1. Create Sources/ILSShared/Models/Skill.swift
2. Define Skill struct with all conformances (Codable, Identifiable, Sendable, Hashable)
3. Define SkillSource enum with Codable support
4. Create SkillParser struct with static methods
5. Implement regex-based frontmatter extraction
6. Integrate Yams for YAML parsing
7. Add proper error types with LocalizedError conformance
8. Verify compilation with `swift build --target ILSShared`

## Acceptance Criteria

1. **Valid SKILL.md Parsing**
   - Given a valid SKILL.md with name and description in frontmatter
   - When calling SkillParser.parse()
   - Then it returns ParsedSkill with correct name, description, and instructions

2. **Missing Frontmatter Error**
   - Given a markdown file without YAML frontmatter
   - When calling SkillParser.parse()
   - Then it throws ParseError.noFrontmatter

3. **Missing Required Field Error**
   - Given frontmatter without "name" field
   - When calling SkillParser.parse()
   - Then it throws ParseError.missingRequiredField("name")

4. **Content Generation**
   - Given name, description, and instructions
   - When calling SkillParser.generateContent()
   - Then it produces valid SKILL.md format with frontmatter

5. **Compilation Success**
   - Given the Skill model and parser
   - When running `swift build --target ILSShared`
   - Then build succeeds with zero errors

## Metadata
- **Complexity**: Medium
- **Labels**: Models, Swift, Shared, Skills, YAML, Parsing
- **Required Skills**: Swift, Regex, Yams/YAML, Error handling
