import SwiftUI

/// ILS Design System
enum ILSTheme {
    // MARK: - Colors

    /// Primary accent color - hot orange
    static let accent = Color(red: 1.0, green: 0.4, blue: 0.0)

    /// Background colors
    static let background = Color(uiColor: .systemBackground)
    static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
    static let tertiaryBackground = Color(uiColor: .tertiarySystemBackground)

    /// Text colors
    static let primaryText = Color(uiColor: .label)
    static let secondaryText = Color(uiColor: .secondaryLabel)
    static let tertiaryText = Color(uiColor: .tertiaryLabel)

    /// Status colors
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    static let info = Color.blue

    /// Message bubble colors
    static let userBubble = accent.opacity(0.15)
    static let assistantBubble = Color(uiColor: .secondarySystemBackground)

    // MARK: - Typography

    static let titleFont = Font.system(.title, design: .default, weight: .bold)
    static let headlineFont = Font.system(.headline, design: .default, weight: .semibold)
    static let bodyFont = Font.system(.body, design: .default)
    static let captionFont = Font.system(.caption, design: .default)
    static let codeFont = Font.system(.body, design: .monospaced)

    // MARK: - Spacing

    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
    static let spacingXL: CGFloat = 32

    // MARK: - Corner Radius

    static let cornerRadiusS: CGFloat = 4
    static let cornerRadiusM: CGFloat = 8
    static let cornerRadiusL: CGFloat = 12
    static let cornerRadiusXL: CGFloat = 16

    // MARK: - Shadows

    static let shadowLight = Color.black.opacity(0.1)
    static let shadowMedium = Color.black.opacity(0.2)
}

// MARK: - View Modifiers

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(ILSTheme.secondaryBackground)
            .cornerRadius(ILSTheme.cornerRadiusL)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, ILSTheme.spacingM)
            .padding(.vertical, ILSTheme.spacingS)
            .background(ILSTheme.accent)
            .foregroundColor(.white)
            .cornerRadius(ILSTheme.cornerRadiusM)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, ILSTheme.spacingM)
            .padding(.vertical, ILSTheme.spacingS)
            .background(ILSTheme.secondaryBackground)
            .foregroundColor(ILSTheme.accent)
            .cornerRadius(ILSTheme.cornerRadiusM)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

// MARK: - Error View Component

/// Reusable error state view with retry button
struct ErrorStateView: View {
    let title: String
    let message: String
    let retryAction: () async -> Void

    init(
        title: String = "Something went wrong",
        message: String,
        retryAction: @escaping () async -> Void
    ) {
        self.title = title
        self.message = message
        self.retryAction = retryAction
    }

    init(error: Error, retryAction: @escaping () async -> Void) {
        self.title = "Connection Error"
        self.message = Self.userFriendlyMessage(from: error)
        self.retryAction = retryAction
    }

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "exclamationmark.triangle")
                .foregroundColor(ILSTheme.error)
        } description: {
            Text(message)
                .foregroundColor(ILSTheme.secondaryText)
        } actions: {
            Button {
                Task {
                    await retryAction()
                }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private static func userFriendlyMessage(from error: Error) -> String {
        let nsError = error as NSError

        // Check for network-related errors
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return "No internet connection. Please check your network settings."
            case NSURLErrorTimedOut:
                return "Request timed out. Please try again."
            case NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost:
                return "Cannot connect to server. Make sure the backend is running."
            case NSURLErrorNetworkConnectionLost:
                return "Network connection was lost. Please try again."
            default:
                return "Network error: \(error.localizedDescription)"
            }
        }

        // Generic error message
        return error.localizedDescription
    }
}

// MARK: - Loading Overlay Modifier

struct LoadingOverlay: ViewModifier {
    let isLoading: Bool
    let message: String?

    func body(content: Content) -> some View {
        content
            .overlay {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.1)
                            .ignoresSafeArea()

                        VStack(spacing: ILSTheme.spacingS) {
                            ProgressView()
                            if let message = message {
                                Text(message)
                                    .font(ILSTheme.captionFont)
                                    .foregroundColor(ILSTheme.secondaryText)
                            }
                        }
                        .padding(ILSTheme.spacingL)
                        .background(ILSTheme.secondaryBackground)
                        .cornerRadius(ILSTheme.cornerRadiusL)
                    }
                }
            }
    }
}

extension View {
    func loadingOverlay(isLoading: Bool, message: String? = nil) -> some View {
        modifier(LoadingOverlay(isLoading: isLoading, message: message))
    }
}

// MARK: - Empty State with Action

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let description: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        title: String,
        systemImage: String,
        description: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(description)
        } actions: {
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
}

// MARK: - Status Badge Component

/// Reusable status badge with colored indicator and text
struct StatusBadge: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.caption2)
                .foregroundColor(color)
        }
    }
}
