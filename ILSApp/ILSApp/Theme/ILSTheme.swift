import SwiftUI

/// ILS Design System
enum ILSTheme {
    // MARK: - Colors

    /// Primary accent color - (#FF6B35)
    static let accent = Color(red: 1.0, green: 107.0/255.0, blue: 53.0/255.0)

    /// Background colors - hardcoded dark theme per DESIGN.md
    static let background = Color(red: 0, green: 0, blue: 0)                                      // #000000 Deep Black
    static let secondaryBackground = Color(red: 13.0/255.0, green: 13.0/255.0, blue: 13.0/255.0)   // #0D0D0D
    static let tertiaryBackground = Color(red: 26.0/255.0, green: 26.0/255.0, blue: 26.0/255.0)   // #1A1A1A

    /// Text colors - hardcoded per DESIGN.md
    static let primaryText = Color.white                                                            // #FFFFFF Pure White
    static let secondaryText = Color(red: 160.0/255.0, green: 160.0/255.0, blue: 160.0/255.0)     // #A0A0A0
    static let tertiaryText = Color(red: 102.0/255.0, green: 102.0/255.0, blue: 102.0/255.0)      // #666666

    /// Status colors - exact DESIGN.md values
    static let success = Color(red: 76.0/255.0, green: 175.0/255.0, blue: 80.0/255.0)              // #4CAF50
    static let warning = Color(red: 1.0, green: 167.0/255.0, blue: 38.0/255.0)                    // #FFA726
    static let error = Color(red: 239.0/255.0, green: 83.0/255.0, blue: 80.0/255.0)               // #EF5350
    static let info = Color(red: 0.0, green: 122.0/255.0, blue: 255.0/255.0)                      // #007AFF Ocean Blue

    /// Message bubble colors
    static let userBubble = Color(red: 1.0, green: 107.0/255.0, blue: 53.0/255.0).opacity(0.15)
    static let assistantBubble = Color(red: 13.0/255.0, green: 13.0/255.0, blue: 13.0/255.0)

    /// List separator color - very dark gray per DESIGN.md
    static let separator = Color(red: 42.0/255.0, green: 42.0/255.0, blue: 42.0/255.0)            // #2A2A2A

    /// Additional accent variants
    static let accentSecondary = Color(red: 1.0, green: 140.0/255.0, blue: 90.0/255.0)               // #FF8C5A
    static let accentTertiary = Color(red: 1.0, green: 69.0/255.0, blue: 0.0)                         // #FF4500

    /// Border colors
    static let borderDefault = Color(red: 42.0/255.0, green: 42.0/255.0, blue: 42.0/255.0)            // #2A2A2A
    static let borderActive = Color(red: 1.0, green: 107.0/255.0, blue: 53.0/255.0)                   // #FF6B35

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

    static let cornerRadiusXS: CGFloat = 4
    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusMedium: CGFloat = 12
    static let cornerRadiusLarge: CGFloat = 16

    // Deprecated aliases - TODO: remove after full migration
    static let cornerRadiusS: CGFloat = 4
    static let cornerRadiusM: CGFloat = 8
    static let cornerRadiusL: CGFloat = 12
    static let cornerRadiusXL: CGFloat = 16

    // MARK: - Shadows

    static let shadowLight = Color.clear  // No shadows on dark theme per DESIGN.md
    // shadowMedium removed - unused
}

// MARK: - View Modifiers

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(ILSTheme.secondaryBackground)
            .cornerRadius(ILSTheme.cornerRadiusMedium)
    }
}

// IMPORTANT: All .sheet() content must include .presentationBackground(Color.black)
// to prevent system dark gray showing behind sheet chrome rounded corners.
// Apply to the outermost view inside the .sheet {} closure.

struct DarkListStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(ILSTheme.background)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, ILSTheme.spacingM)
            .padding(.vertical, ILSTheme.spacingS)
            .background(ILSTheme.accent)
            .foregroundColor(.white)
            .cornerRadius(ILSTheme.cornerRadiusSmall)
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
            .cornerRadius(ILSTheme.cornerRadiusSmall)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }

    func darkListStyle() -> some View {
        modifier(DarkListStyle())
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
                        Color.white.opacity(0.05)
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
                        .cornerRadius(ILSTheme.cornerRadiusMedium)
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

struct StatusBadge: View {
    let text: String
    let color: Color

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

// MARK: - Haptic Feedback Manager

enum HapticManager {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

// MARK: - Toast Component

struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isPresented {
                    Text(message)
                        .font(ILSTheme.captionFont)
                        .foregroundColor(.white)
                        .padding(.horizontal, ILSTheme.spacingM)
                        .padding(.vertical, ILSTheme.spacingS)
                        .background(ILSTheme.tertiaryBackground)
                        .cornerRadius(ILSTheme.cornerRadiusSmall)
                        .shadow(color: .black.opacity(0.3), radius: 4)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isPresented)
    }
}

extension View {
    func toast(isPresented: Binding<Bool>, message: String) -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message))
    }

    /// Show toast then auto-dismiss after duration
    func showToast(_ binding: Binding<Bool>, duration: TimeInterval = 2) {
        binding.wrappedValue = true
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            binding.wrappedValue = false
        }
    }
}
