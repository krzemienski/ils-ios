# Technology Stack

**Analysis Date:** 2026-02-19

## Languages

**Primary:**
- Swift 5.9+ - iOS app (`ILSApp/ILSApp/`), macOS app (`ILSApp/ILSMacApp/`), backend (`Sources/ILSBackend/`), shared models (`Sources/ILSShared/`)
- Python 3 - SDK wrapper script for Claude execution (`scripts/sdk-wrapper.py`)

**Secondary:**
- XML/YAML - Configuration files (`project.yml`, `Info.plist`)

## Runtime

**Environment:**
- iOS 17.0+ (minimum deployment target)
- macOS 14.0+ (minimum deployment target)
- Xcode 16.0 (xcodeVersion in project.yml)
- Swift 5.0+ (SWIFT_VERSION in build settings)

**Package Manager:**
- Swift Package Manager (SPM) - Primary dependency management
- Xcode 16.0 with XcodeGen 2.x (generates Xcode project from `project.yml`)
- Fastlane - App Store automation (fastlane directory present)

## Frameworks

**Core:**
- SwiftUI - UI framework for both iOS and macOS apps
- Observation - State management (@Observable macro for iOS 17+)
- Combine - Reactive programming (legacy support in SSEClient, transitioning to Observation)
- Foundation - Core runtime

**Backend:**
- Vapor 4.89.0+ - Web framework for REST/WebSocket API server
- Fluent 4.9.0+ - ORM for database access
- FluentSQLiteDriver 4.6.0+ - SQLite persistence driver

**UI Components (iOS/macOS):**
- MarkdownUI 2.4.0+ - Markdown rendering with syntax highlighting
- HighlightSwift 1.0.0+ - Code syntax highlighting
- Splash 0.16.0+ - Swift syntax highlighting library (shared)
- Citadel 0.7.1+ - SSH client library for remote connections

**Data Storage:**
- GRDB 7.0.0+ - SQLite toolkit with type-safe queries (iOS/macOS client-side caching)
- Fluent SQLite - Backend server-side persistence

**Testing:**
- XCTest - Native testing framework (with XCTVapor for backend)

**Build/Dev:**
- SwiftLint - Code style linting (configuration: `.swiftlint.yml`)

## Key Dependencies

**Critical:**
- Vapor 4.89.0 - Backend REST/streaming API server. Why: Core infrastructure for all client communication
- Fluent + FluentSQLiteDriver - Backend persistence. Why: Stores sessions, projects, themes, cached results
- ILSShared (local package) - Shared models (ChatSession, Message, CLIMessage, etc.). Why: Single source of truth for iOS/macOS/backend data contracts
- MarkdownUI 2.4.0 - Renders Claude responses with markdown. Why: Core UX requirement for readable AI output
- Citadel 0.7.1 - SSH connectivity for remote fleet management. Why: Enables agent execution on remote hosts

**Infrastructure:**
- Yams 5.0.0 - YAML parsing for skill configuration files on backend
- Splash 0.16.0 - Swift-specific syntax highlighting in shared layer
- HighlightSwift 1.0.0 - Multi-language code highlighting for iOS/macOS views
- GRDB 7.0.0 - Client-side local SQLite caching for offline resilience

## Configuration

**Environment:**
- Backend configuration via environment variables:
  - `PORT` - Server listen port (default: 9999)
  - `ILS_CORS_ORIGINS` - Comma-separated CORS origins (default: localhost:3000,8080,9999)
  - `GITHUB_TOKEN` - GitHub API authentication for marketplace search (optional)
  - `ILS_API_KEY` - Optional API key for backend authentication (stored in Keychain on iOS/macOS)

- iOS/macOS app configuration:
  - Server URL via AppConstants.defaultServerURL (persisted in UserDefaults, migrates to Keychain)
  - Credentials stored in iOS Keychain with optional biometric protection (Face ID/Touch ID)

**Build:**
- `project.yml` - XcodeGen project configuration (generates .xcodeproj)
- `Package.swift` - Swift Package Manager manifest (iOS 17.0+, macOS 14.0+)
- `.swiftlint.yml` - Code style rules (line_length: 200 warning/300 error, file_length: 600 warning/1000 error)
- `ILSApp/ILSApp.xcodeproj/` - Generated Xcode project (iOS + macOS schemes)
- Build schemes:
  - `ILSApp` - iOS app only
  - `ILSMacApp` - macOS app only
  - `ILSApp-WithBackend` - iOS app with backend pre-launch
  - `ILSMacApp-WithBackend` - macOS app with backend pre-launch
  - `ILSAppUITests` - UI tests for iOS

## Platform Requirements

**Development:**
- Xcode 16.0+ on macOS
- Swift Toolchain 5.9+
- iOS Simulator with iOS 18.6 (UDID: 50523130-57AA-48B0-ABD0-4D59CE455F14 — dedicated for this project)
- Python 3 (for SDK wrapper script)
- Cloudflared binary (optional, for tunnel support)
- Git (for plugin marketplace git clone)

**Production:**
- Deployment: iOS 17.0+ (App Store), macOS 14.0+ (App Store)
- Backend: Runs as Swift executable on localhost:9999 or via Cloudflare tunnel
- Database: SQLite at `ils.sqlite` (local file, auto-created at app startup)

**Bundle IDs:**
- iOS: `com.ils.app`
- macOS: `com.ils.mac`
- UI Tests: `com.ils.app.uitests`

**Developer Team:**
- Team ID: HC36V7B67Z (for code signing)

---

*Stack analysis: 2026-02-19*
