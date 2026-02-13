import SwiftUI

/// ILS Design System
enum ILSTheme {
    // MARK: - Colors

    /// Primary accent color - hot orange
    static let accent = Color(red: 1.0, green: 0.4, blue: 0.0)

    /// Background colors
    #if os(iOS)
    static let background = Color(uiColor: .systemBackground)
    static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
    static let tertiaryBackground = Color(uiColor: .tertiarySystemBackground)
    #else
    static let background = Color(nsColor: .windowBackgroundColor)
    static let secondaryBackground = Color(nsColor: .controlBackgroundColor)
    static let tertiaryBackground = Color(nsColor: .textBackgroundColor)
    #endif

    /// Text colors
    #if os(iOS)
    static let primaryText = Color(uiColor: .label)
    static let secondaryText = Color(uiColor: .secondaryLabel)
    static let tertiaryText = Color(uiColor: .tertiaryLabel)
    #else
    static let primaryText = Color(nsColor: .labelColor)
    static let secondaryText = Color(nsColor: .secondaryLabelColor)
    static let tertiaryText = Color(nsColor: .tertiaryLabelColor)
    #endif

    /// Status colors
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    static let info = Color.blue

    /// Message bubble colors
    static let userBubble = accent.opacity(0.15)
    #if os(iOS)
    static let assistantBubble = Color(uiColor: .secondarySystemBackground)
    #else
    static let assistantBubble = Color(nsColor: .controlBackgroundColor)
    #endif

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

// MARK: - Color Palette Presets

/// Material Design color palette
/// Based on Material Design 3 color system
struct MaterialPalette {
    static let primary = Color(red: 0.38, green: 0.49, blue: 0.98)        // Indigo 500
    static let primaryVariant = Color(red: 0.24, green: 0.32, blue: 0.71) // Indigo 700
    static let secondary = Color(red: 0.0, green: 0.74, blue: 0.83)       // Cyan 500
    static let secondaryVariant = Color(red: 0.0, green: 0.6, blue: 0.68) // Cyan 700
    static let accent = Color(red: 1.0, green: 0.34, blue: 0.13)          // Deep Orange 500
    static let success = Color(red: 0.3, green: 0.69, blue: 0.31)         // Green 500
    static let warning = Color(red: 1.0, green: 0.6, blue: 0.0)           // Orange 500
    static let error = Color(red: 0.96, green: 0.26, blue: 0.21)          // Red 500
    static let info = Color(red: 0.13, green: 0.59, blue: 0.95)           // Blue 500

    static let background = Color(red: 0.98, green: 0.98, blue: 0.98)
    static let surface = Color.white
    static let onPrimary = Color.white
    static let onSecondary = Color.black
    static let onBackground = Color.black.opacity(0.87)
    static let onSurface = Color.black.opacity(0.87)
}

/// Tailwind CSS color palette
/// Based on Tailwind CSS default colors
struct TailwindPalette {
    static let slate500 = Color(red: 0.39, green: 0.45, blue: 0.55)
    static let gray500 = Color(red: 0.42, green: 0.45, blue: 0.5)
    static let zinc500 = Color(red: 0.44, green: 0.46, blue: 0.5)
    static let neutral500 = Color(red: 0.45, green: 0.46, blue: 0.48)

    static let red500 = Color(red: 0.94, green: 0.27, blue: 0.27)
    static let orange500 = Color(red: 0.98, green: 0.55, blue: 0.24)
    static let amber500 = Color(red: 0.96, green: 0.62, blue: 0.07)
    static let yellow500 = Color(red: 0.92, green: 0.76, blue: 0.22)
    static let lime500 = Color(red: 0.52, green: 0.83, blue: 0.18)
    static let green500 = Color(red: 0.13, green: 0.8, blue: 0.45)
    static let emerald500 = Color(red: 0.06, green: 0.73, blue: 0.52)
    static let teal500 = Color(red: 0.08, green: 0.66, blue: 0.62)
    static let cyan500 = Color(red: 0.02, green: 0.73, blue: 0.83)
    static let sky500 = Color(red: 0.05, green: 0.68, blue: 0.93)
    static let blue500 = Color(red: 0.23, green: 0.51, blue: 0.98)
    static let indigo500 = Color(red: 0.39, green: 0.42, blue: 0.93)
    static let violet500 = Color(red: 0.55, green: 0.42, blue: 0.95)
    static let purple500 = Color(red: 0.66, green: 0.39, blue: 0.92)
    static let fuchsia500 = Color(red: 0.85, green: 0.27, blue: 0.84)
    static let pink500 = Color(red: 0.93, green: 0.26, blue: 0.59)
    static let rose500 = Color(red: 0.96, green: 0.26, blue: 0.45)

    // Common theme colors using Tailwind palette
    static let primary = blue500
    static let secondary = slate500
    static let accent = violet500
    static let success = green500
    static let warning = amber500
    static let error = red500
    static let info = sky500
}

/// iOS Native color palette
/// Uses iOS system colors for native feel
struct NativePalette {
    static let primary = Color.blue
    static let secondary = Color.gray
    static let accent = Color.accentColor
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    static let info = Color.blue

    #if os(iOS)
    static let background = Color(uiColor: .systemBackground)
    static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
    static let tertiaryBackground = Color(uiColor: .tertiarySystemBackground)
    static let primaryText = Color(uiColor: .label)
    static let secondaryText = Color(uiColor: .secondaryLabel)
    static let tertiaryText = Color(uiColor: .tertiaryLabel)
    #else
    static let background = Color(nsColor: .windowBackgroundColor)
    static let secondaryBackground = Color(nsColor: .controlBackgroundColor)
    static let tertiaryBackground = Color(nsColor: .textBackgroundColor)
    static let primaryText = Color(nsColor: .labelColor)
    static let secondaryText = Color(nsColor: .secondaryLabelColor)
    static let tertiaryText = Color(nsColor: .tertiaryLabelColor)
    #endif
}

/// Nord color palette
/// Popular Arctic-inspired color scheme
struct NordPalette {
    // Polar Night (dark backgrounds)
    static let nord0 = Color(red: 0.18, green: 0.2, blue: 0.25)
    static let nord1 = Color(red: 0.23, green: 0.26, blue: 0.31)
    static let nord2 = Color(red: 0.26, green: 0.3, blue: 0.35)
    static let nord3 = Color(red: 0.3, green: 0.34, blue: 0.41)

    // Snow Storm (light backgrounds)
    static let nord4 = Color(red: 0.85, green: 0.87, blue: 0.91)
    static let nord5 = Color(red: 0.9, green: 0.91, blue: 0.94)
    static let nord6 = Color(red: 0.93, green: 0.94, blue: 0.96)

    // Frost (accent colors)
    static let nord7 = Color(red: 0.56, green: 0.74, blue: 0.73)
    static let nord8 = Color(red: 0.53, green: 0.75, blue: 0.82)
    static let nord9 = Color(red: 0.51, green: 0.63, blue: 0.76)
    static let nord10 = Color(red: 0.37, green: 0.51, blue: 0.68)

    // Aurora (vibrant colors)
    static let nord11 = Color(red: 0.75, green: 0.38, blue: 0.42) // Red
    static let nord12 = Color(red: 0.82, green: 0.53, blue: 0.44) // Orange
    static let nord13 = Color(red: 0.92, green: 0.8, blue: 0.55)  // Yellow
    static let nord14 = Color(red: 0.64, green: 0.75, blue: 0.54) // Green
    static let nord15 = Color(red: 0.71, green: 0.56, blue: 0.68) // Purple

    // Common theme colors
    static let primary = nord10
    static let secondary = nord9
    static let accent = nord8
    static let success = nord14
    static let warning = nord13
    static let error = nord11
    static let info = nord8
    static let background = nord0
    static let surface = nord1
    static let text = nord4
}

/// Dracula color palette
/// Popular dark theme
struct DraculaPalette {
    static let background = Color(red: 0.16, green: 0.16, blue: 0.21)
    static let currentLine = Color(red: 0.27, green: 0.28, blue: 0.35)
    static let selection = Color(red: 0.27, green: 0.28, blue: 0.35)
    static let foreground = Color(red: 0.95, green: 0.95, blue: 0.95)
    static let comment = Color(red: 0.38, green: 0.47, blue: 0.64)

    static let cyan = Color(red: 0.55, green: 1.0, blue: 0.99)
    static let green = Color(red: 0.31, green: 0.98, blue: 0.48)
    static let orange = Color(red: 1.0, green: 0.71, blue: 0.42)
    static let pink = Color(red: 1.0, green: 0.47, blue: 0.78)
    static let purple = Color(red: 0.74, green: 0.58, blue: 0.98)
    static let red = Color(red: 1.0, green: 0.33, blue: 0.33)
    static let yellow = Color(red: 0.95, green: 0.98, blue: 0.55)

    // Common theme colors
    static let primary = purple
    static let secondary = pink
    static let accent = cyan
    static let success = green
    static let warning = yellow
    static let error = red
    static let info = cyan
    static let text = foreground
}

/// Solarized color palette
/// Popular low-contrast color scheme
struct SolarizedPalette {
    // Base colors
    static let base03 = Color(red: 0.0, green: 0.17, blue: 0.21)   // Dark background
    static let base02 = Color(red: 0.03, green: 0.21, blue: 0.26)
    static let base01 = Color(red: 0.35, green: 0.43, blue: 0.46)
    static let base00 = Color(red: 0.4, green: 0.48, blue: 0.51)
    static let base0 = Color(red: 0.51, green: 0.58, blue: 0.59)
    static let base1 = Color(red: 0.58, green: 0.63, blue: 0.63)
    static let base2 = Color(red: 0.93, green: 0.91, blue: 0.84)
    static let base3 = Color(red: 0.99, green: 0.96, blue: 0.89)   // Light background

    // Accent colors
    static let yellow = Color(red: 0.71, green: 0.54, blue: 0.0)
    static let orange = Color(red: 0.8, green: 0.29, blue: 0.09)
    static let red = Color(red: 0.86, green: 0.2, blue: 0.18)
    static let magenta = Color(red: 0.83, green: 0.21, blue: 0.51)
    static let violet = Color(red: 0.42, green: 0.44, blue: 0.77)
    static let blue = Color(red: 0.15, green: 0.55, blue: 0.82)
    static let cyan = Color(red: 0.16, green: 0.63, blue: 0.6)
    static let green = Color(red: 0.52, green: 0.6, blue: 0.0)

    // Common theme colors (dark variant)
    static let primary = blue
    static let secondary = cyan
    static let accent = violet
    static let success = green
    static let warning = yellow
    static let error = red
    static let info = blue
    static let background = base03
    static let surface = base02
    static let text = base0
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
