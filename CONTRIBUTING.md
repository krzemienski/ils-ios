# Contributing to ILS

Thank you for your interest in contributing to ILS! This document provides guidelines and information for contributors.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment. Be kind, constructive, and professional in all interactions.

## Getting Started

### Prerequisites

- macOS 14.0+ (Sonoma or later)
- Xcode 15.0+ with iOS 17 SDK
- Swift 5.9+
- Git

### Setting Up Your Development Environment

1. **Fork the repository** on GitHub

2. **Clone your fork**
   ```bash
   git clone https://github.com/YOUR_USERNAME/ils-ios.git
   cd ils-ios
   ```

3. **Build the backend**
   ```bash
   swift build
   swift run ILSBackend
   ```

4. **Open the iOS project**
   ```bash
   open ILSApp/ILSApp.xcodeproj
   ```

5. **Run the app** in Xcode (Cmd+R)

## Project Structure

```
ils-ios/
├── Sources/
│   ├── ILSShared/        # Shared models (iOS + Backend)
│   └── ILSBackend/       # Vapor backend server
├── ILSApp/               # iOS application
├── Tests/                # Backend tests
└── docs/                 # Documentation
```

## How to Contribute

### Reporting Bugs

1. **Search existing issues** to avoid duplicates
2. **Create a new issue** with:
   - Clear, descriptive title
   - Steps to reproduce
   - Expected vs actual behavior
   - iOS version, Xcode version, device/simulator info
   - Screenshots if applicable

### Suggesting Features

1. **Open a discussion** or issue with `[Feature Request]` prefix
2. Describe the feature and its use case
3. Explain why it would benefit users

### Submitting Code

#### 1. Create a Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/issue-description
```

#### 2. Make Your Changes

- Follow the existing code style
- Write clear commit messages
- Add tests for new functionality
- Update documentation if needed

#### 3. Test Your Changes

**Backend:**
```bash
swift test
```

**iOS App:**
- Build and run on Simulator
- Test on multiple device sizes (iPhone, iPad)
- Verify both light and dark modes work (currently dark-only)

#### 4. Submit a Pull Request

1. Push your branch to your fork
2. Open a PR against the `main` branch
3. Fill out the PR template
4. Link related issues

## Code Style Guidelines

### Swift Style

- Use Swift's standard naming conventions
- Prefer `let` over `var` when possible
- Use meaningful variable and function names
- Add documentation comments for public APIs

### SwiftUI

- Keep views focused and composable
- Extract reusable components
- Use `@ViewBuilder` for complex conditional views
- Prefer `@StateObject` for view models, `@State` for local state

### MVVM Pattern

- Views should be declarative and free of business logic
- ViewModels handle data fetching and state management
- Models are plain data structures

### Example

```swift
// Good: Clear naming, proper structure
struct SessionsListView: View {
    @StateObject private var viewModel = SessionsViewModel()

    var body: some View {
        List(viewModel.sessions) { session in
            SessionRowView(session: session)
        }
        .task {
            await viewModel.loadSessions()
        }
    }
}

// ViewModel
@MainActor
class SessionsViewModel: ObservableObject {
    @Published var sessions: [ChatSession] = []
    @Published var isLoading = false
    @Published var error: Error?

    func loadSessions() async {
        isLoading = true
        defer { isLoading = false }

        do {
            sessions = try await apiClient.getSessions()
        } catch {
            self.error = error
        }
    }
}
```

## Backend Development

### Adding a New Endpoint

1. **Create/update controller** in `Sources/ILSBackend/Controllers/`
2. **Add route** in `Sources/ILSBackend/App/routes.swift`
3. **Add shared models** in `Sources/ILSShared/Models/` if needed
4. **Test the endpoint**
   ```bash
   curl http://localhost:9090/api/v1/your-endpoint
   ```

### Database Migrations

When modifying the database schema:

1. Create a new migration in `Sources/ILSBackend/Migrations/`
2. Register it in `configure.swift`
3. Test with a fresh database (`rm ils.sqlite`)

## iOS Development

### Adding a New Feature

1. **Create ViewModel** in `ILSApp/ViewModels/`
2. **Create View(s)** in `ILSApp/Views/YourFeature/`
3. **Add navigation** in `ContentView.swift` or `SidebarView.swift`
4. **Update shared models** if needed

### Theming

Use `ILSTheme` for consistent styling:

```swift
Text("Hello")
    .font(ILSTheme.bodyFont)
    .foregroundColor(ILSTheme.primaryText)
    .padding(ILSTheme.spacingM)
```

## Testing

### What to Test

- ViewModel logic and state management
- API response parsing
- Error handling
- Edge cases (empty states, loading states)

### Running Tests

```bash
# Backend
swift test

# iOS (from Xcode or command line)
xcodebuild test -scheme ILSApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

## Documentation

- Update README.md for user-facing changes
- Update CHANGELOG.md for all notable changes
- Add inline documentation for complex code
- Update API documentation for endpoint changes

## Release Process

1. Update version in appropriate files
2. Update CHANGELOG.md
3. Create a tagged release
4. Build and archive iOS app (for App Store, if applicable)

## Questions?

- Open a GitHub Discussion for general questions
- Tag maintainers in issues if you need guidance
- Be patient - maintainers are volunteers

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to ILS!
