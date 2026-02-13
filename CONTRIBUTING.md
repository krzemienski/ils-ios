# Contributing to ILS

Welcome! ILS is a native iOS and macOS client for Claude Code, providing a rich interface for AI-powered development workflows. We appreciate your interest in contributing.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment. Be kind, constructive, and professional in all interactions.

## Development Setup

### Prerequisites

- macOS 14.0 or later
- Xcode 15.0 or later
- Swift 6.0 or later

### Getting Started

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/ils-ios.git
   cd ils-ios
   ```

2. **Run setup script**
   ```bash
   scripts/setup.sh
   ```

3. **Open in Xcode**
   ```bash
   open ILSApp/ILSApp.xcodeproj
   ```

4. **Select your target**
   - For iOS development: Select the **ILSApp** scheme
   - For macOS development: Select the **ILSMacApp** scheme

### Running the Backend

The ILS backend server provides API endpoints for sessions, projects, skills, and more.

```bash
PORT=9999 swift run ILSBackend
```

The backend will start on port 9999 by default. See `docs/RUNNING_BACKEND.md` for more details.

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

## Issue Reporting

Found a bug or have a feature request? Please use our GitHub issue templates:

- **Bug Report**: For reporting bugs in the iOS app, macOS app, or backend
- **Feature Request**: For suggesting new features or improvements

### What to Include

- Device and OS information
- App version and build number
- Steps to reproduce (for bugs)
- Screenshots or screen recordings (when applicable)

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

#### 4. Build and Verify

```bash
swift build
```

Also build in Xcode to ensure iOS/macOS targets compile without warnings.

#### 5. Submit a Pull Request

1. Push your branch to your fork
2. Open a PR against the `master` branch
3. Fill out the PR template
4. Link related issues

### Pull Request Guidelines

- Keep PRs focused on a single feature or fix
- Include a clear title and description
- Add screenshots for UI changes
- Ensure all builds pass without warnings
- Respond to review feedback promptly

## Code Style

We use SwiftLint to enforce consistent code style across the project.

### Before Committing

1. **Run SwiftLint**
   ```bash
   swiftlint lint
   ```

2. **Fix auto-fixable issues**
   ```bash
   swiftlint --fix
   ```

Our SwiftLint configuration is defined in `.swiftlint.yml` at the repository root.

### Key Style Guidelines

- Use 2-space indentation
- Follow Swift API Design Guidelines
- Prefer immutable data structures
- Keep files focused and under 800 lines
- Write descriptive variable and function names

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
