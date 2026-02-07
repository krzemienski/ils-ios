import SwiftUI
import MarkdownUI

/// Collapsible section for displaying AI thinking/reasoning in chat messages.
/// Shows pulsing brain icon when active, static when complete.
struct ThinkingSection: View {
    let thinking: String
    let isActive: Bool

    @State private var isExpanded = false
    @State private var pulseScale: CGFloat = 1.0

    /// Dark background
    private let sectionBg = Color(red: 17.0/255.0, green: 24.0/255.0, blue: 39.0/255.0)
    /// Border color
    private let borderColor = Color.white.opacity(0.06)
    /// Brain icon color
    private let brainColor = Color(red: 168.0/255.0, green: 85.0/255.0, blue: 247.0/255.0)

    init(thinking: String, isActive: Bool = false) {
        self.thinking = thinking
        self.isActive = isActive
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: ILSTheme.spacingS) {
                    Image(systemName: "brain")
                        .font(.system(.caption, weight: .medium))
                        .foregroundColor(brainColor)
                        .scaleEffect(pulseScale)
                        .frame(width: 20)

                    Text(isActive ? "Thinking..." : "Thinking (\(thinking.count.formatted()) chars)")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundColor(ILSTheme.textPrimary)

                    if isActive {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(brainColor)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(ILSTheme.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, ILSTheme.spacingS)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            // Expanded thinking text
            if isExpanded {
                ScrollView {
                    Markdown(thinking)
                        .markdownTheme(.ilsChat)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 400)
                .padding(.horizontal, ILSTheme.spacingS)
                .padding(.bottom, ILSTheme.spacingS)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(sectionBg)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(isActive ? "AI thinking process, in progress" : "AI thinking process")
        .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand")
        .onAppear {
            if isActive && !UIAccessibility.isReduceMotionEnabled {
                startPulsing()
            }
        }
        .onChange(of: isActive) { _, active in
            if active && !UIAccessibility.isReduceMotionEnabled {
                startPulsing()
            } else {
                pulseScale = 1.0
            }
        }
    }

    private func startPulsing() {
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ThinkingSection(
            thinking: "Let me analyze the code structure and identify the best approach for implementing this feature. I need to consider the existing patterns and ensure backward compatibility...",
            isActive: true
        )

        ThinkingSection(
            thinking: "Let me analyze the code structure and identify the **best approach** for implementing this feature.\n\n- Consider existing patterns\n- Ensure backward compatibility\n- Check for `edge cases`",
            isActive: false
        )
    }
    .padding()
    .background(Color.black)
}
