import SwiftUI
import MarkdownUI

/// Collapsible section for displaying AI thinking/reasoning in chat messages.
/// Shows pulsing brain icon when active, static when complete.
/// Collapsed by default — expanded shows italic content.
struct ThinkingSection: View {
    let thinking: String
    let isActive: Bool

    @State private var isExpanded = false
    @State private var pulseScale: CGFloat = 1.0

    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(thinking: String, isActive: Bool = false) {
        self.thinking = thinking
        self.isActive = isActive
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerButton

            if isExpanded {
                expandedContent
            }
        }
        .background(theme.bgTertiary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                .strokeBorder(theme.borderSubtle, lineWidth: 0.5)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(isActive ? "AI thinking process, in progress" : "AI thinking process")
        .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand")
        .onAppear {
            if isActive && !reduceMotion {
                startPulsing()
            }
        }
        .onChange(of: isActive) { _, active in
            if active && !reduceMotion {
                startPulsing()
            } else {
                pulseScale = 1.0
            }
        }
    }

    // MARK: - Header

    private var headerButton: some View {
        Button {
            if reduceMotion {
                isExpanded.toggle()
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
        } label: {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "brain")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.entityPlugin)
                    .scaleEffect(pulseScale)
                    .frame(width: 20)

                if isActive {
                    Text("Thinking...")
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(theme.entityPlugin)
                } else {
                    Text("Thinking")
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Text("·")
                        .foregroundStyle(theme.textTertiary)
                    Text(durationText)
                        .font(.system(size: 10, design: theme.fontDesign).leading(.tight))
                        .foregroundStyle(theme.textTertiary)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, design: theme.fontDesign).leading(.tight))
                    .foregroundStyle(theme.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, theme.spacingSM)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        ScrollView {
            Text(thinking)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign).italic())
                .foregroundStyle(theme.textSecondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 400)
        .padding(.horizontal, theme.spacingSM)
        .padding(.bottom, theme.spacingSM)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Helpers

    private var durationText: String {
        let charCount = thinking.count
        if charCount > 1000 {
            return "\(charCount / 1000)k chars"
        }
        return "\(charCount) chars"
    }

    private func startPulsing() {
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
        }
    }
}
