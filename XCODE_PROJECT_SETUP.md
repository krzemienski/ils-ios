# Xcode Project Setup Required

## Files Created

The following Swift files have been created for syntax-highlighted code blocks:

1. `ILSApp/ILSApp/Utils/MarkdownParser.swift` - Parses markdown to extract code blocks
2. `ILSApp/ILSApp/Utils/SyntaxHighlighter.swift` - Wrapper around Splash library for syntax highlighting
3. `ILSApp/ILSApp/Views/Chat/CodeBlockView.swift` - SwiftUI view for displaying code blocks

## Required: Add Files to Xcode Project

These files need to be added to the Xcode project file (`ILSApp/ILSApp.xcodeproj/project.pbxproj`).

### Option 1: Using Xcode (Recommended)

1. Open `ILSApp/ILSApp.xcodeproj` in Xcode
2. Right-click on the "ILSApp" group in the Project Navigator
3. Select "Add Files to ILSApp"
4. Navigate to and select:
   - `ILSApp/Utils/MarkdownParser.swift`
   - `ILSApp/Utils/SyntaxHighlighter.swift`
5. Right-click on the "Views/Chat" group
6. Select "Add Files to ILSApp"
7. Navigate to and select:
   - `ILSApp/Views/Chat/CodeBlockView.swift`
8. Build the project to verify

### Option 2: Manual Project File Editing

Add the following entries to `project.pbxproj`:

**PBXBuildFile section** (after line 42):
```
00000000000000000000008A /* MarkdownParser.swift in Sources */ = {isa = PBXBuildFile; fileRef = 00000000000000000000009A /* MarkdownParser.swift */; };
00000000000000000000008B /* SyntaxHighlighter.swift in Sources */ = {isa = PBXBuildFile; fileRef = 00000000000000000000009B /* SyntaxHighlighter.swift */; };
00000000000000000000008C /* CodeBlockView.swift in Sources */ = {isa = PBXBuildFile; fileRef = 00000000000000000000009C /* CodeBlockView.swift */; };
```

**PBXFileReference section** (after line 90):
```
00000000000000000000009A /* MarkdownParser.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MarkdownParser.swift; sourceTree = "<group>"; };
00000000000000000000009B /* SyntaxHighlighter.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SyntaxHighlighter.swift; sourceTree = "<group>"; };
00000000000000000000009C /* CodeBlockView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = CodeBlockView.swift; sourceTree = "<group>"; };
```

**Utils Group** (after Dashboard group, before UITest group):
```
000000000000000000000079 /* Utils */ = {
    isa = PBXGroup;
    children = (
        00000000000000000000009A /* MarkdownParser.swift */,
        00000000000000000000009B /* SyntaxHighlighter.swift */,
    );
    path = Utils;
    sourceTree = "<group>";
};
```

**Add Utils to ILSApp group children** (in group 000000000000000000000015):
```
000000000000000000000079 /* Utils */,
```

**Add CodeBlockView to Chat group children** (in group 000000000000000000000071):
```
00000000000000000000009C /* CodeBlockView.swift */,
```

**PBXSourcesBuildPhase section** (add before closing of section ~line 421):
```
00000000000000000000008A /* MarkdownParser.swift in Sources */,
00000000000000000000008B /* SyntaxHighlighter.swift in Sources */,
00000000000000000000008C /* CodeBlockView.swift in Sources */,
```

## Dependencies

The Splash library has been added to `Package.swift` and resolved successfully.

## Build Verification

After adding files to the Xcode project, verify with:
```bash
cd ILSApp && xcodebuild -scheme ILSApp -destination 'platform=iOS Simulator,id=BECB3FA0-518E-4F80-8B8E-7E10C16F3B36' build
```
