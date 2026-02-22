import SwiftUI

/// iMessage-style three-dot animated typing indicator shown while waiting
/// for the first streaming token from Claude.
struct TypingIndicatorBubble: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var animating = false

    private let dotCount = 3
    private let dotSize: CGFloat = 7
    private let dotSpacing: CGFloat = 5
    private let animationDuration: Double = 0.45
    private let animationDelay: Double = 0.15

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Leading accent bar to match AssistantCard
            RoundedRectangle(cornerRadius: 1)
                .fill(theme.accent)
                .frame(width: 2, height: 24)
                .padding(.vertical, 2)

            HStack(spacing: dotSpacing) {
                ForEach(0..<dotCount, id: \.self) { index in
                    Circle()
                        .fill(theme.textTertiary)
                        .frame(width: dotSize, height: dotSize)
                        .offset(y: animating && !reduceMotion ? -5 : 0)
                        .opacity(animating ? 1.0 : 0.4)
                        .animation(
                            reduceMotion
                                ? .none
                                : .easeInOut(duration: animationDuration)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * animationDelay),
                            value: animating
                        )
                }
            }
            .padding(.leading, 10)
            .padding(.vertical, 8)
        }
        .onAppear {
            animating = true
        }
        .onChange(of: scenePhase) { _, phase in
            animating = phase == .active
        }
        .accessibilityLabel("Claude is typing")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

#Preview {
    TypingIndicatorBubble()
        .padding()
        .background(Color.black)
}
