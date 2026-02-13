import SwiftUI

// MARK: - Haptic Feedback Manager

#if os(iOS)
enum HapticManager {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}
#else
// macOS has no haptic feedback
enum HapticManager {
    enum FeedbackStyle { case medium }
    enum FeedbackType { case success, warning, error }
    static func impact(_ style: FeedbackStyle = .medium) {}
    static func notification(_ type: FeedbackType) {}
}
#endif

// MARK: - Toast Component

enum ToastVariant {
    case info
    case success
    case warning
    case error

    func backgroundColor(from theme: any AppTheme) -> Color {
        switch self {
        case .info: return theme.bgTertiary
        case .success: return theme.success.opacity(0.9)
        case .warning: return theme.warning.opacity(0.9)
        case .error: return theme.error.opacity(0.9)
        }
    }

    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
}

struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let variant: ToastVariant
    @Environment(\.theme) private var theme: any AppTheme

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isPresented {
                    HStack(spacing: 8) {
                        Image(systemName: variant.icon)
                            .font(.caption)
                        Text(message)
                            .font(.system(size: theme.fontCaption))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, theme.spacingMD)
                    .padding(.vertical, theme.spacingSM)
                    .background(variant.backgroundColor(from: theme))
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                    .shadow(color: .black.opacity(0.3), radius: 4)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isPresented)
    }
}

extension View {
    func toast(isPresented: Binding<Bool>, message: String, variant: ToastVariant = .info) -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message, variant: variant))
    }
}

// MARK: - Error View Component (used by ServerSetupSheet — migrates in Task 10.1)

/// Reusable error state view with retry button
struct ErrorStateView: View {
    let title: String
    let message: String
    let retryAction: () async -> Void
    @Environment(\.theme) private var theme: any AppTheme

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
                .foregroundColor(theme.error)
        } description: {
            Text(message)
                .foregroundColor(theme.textSecondary)
        } actions: {
            Button {
                Task {
                    await retryAction()
                }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .font(.system(size: theme.fontBody, weight: .semibold))
            .foregroundColor(theme.textOnAccent)
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingSM)
            .background(theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
    }

    private static func userFriendlyMessage(from error: Error) -> String {
        let nsError = error as NSError

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

        return error.localizedDescription
    }
}

// MARK: - Loading Overlay Modifier

struct LoadingOverlay: ViewModifier {
    let isLoading: Bool
    let message: String?
    @Environment(\.theme) private var theme: any AppTheme

    func body(content: Content) -> some View {
        content
            .overlay {
                if isLoading {
                    ZStack {
                        Color.white.opacity(0.05)
                            .ignoresSafeArea()

                        VStack(spacing: theme.spacingSM) {
                            ProgressView()
                            if let message = message {
                                Text(message)
                                    .font(.system(size: theme.fontCaption))
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                        .padding(theme.spacingLG)
                        .background(theme.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
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

// MARK: - Status Badge Component

struct StatusBadge: View {
    let text: String
    let color: Color
    let icon: String

    init(text: String, color: Color, icon: String = "circle.fill") {
        self.text = text
        self.color = color
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .imageScale(.small)
                .foregroundColor(color)
            Text(text)
                .font(.caption2)
                .foregroundColor(color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(text) status")
    }
}
