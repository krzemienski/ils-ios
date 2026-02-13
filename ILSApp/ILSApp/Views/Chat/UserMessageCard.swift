import SwiftUI

/// Compact right-aligned user message pill on pure black background.
/// Max-width 80%, dark surface with no border stroke.
struct UserMessageCard: View {
    let message: ChatMessage
    var onDelete: ((ChatMessage) -> Void)?

    @Environment(\.theme) private var theme: any AppTheme
    @State private var showCopyConfirmation = false

    var body: some View {
        HStack {
            #if os(iOS)
            Spacer(minLength: UIScreen.main.bounds.width * 0.2)
            #else
            Spacer(minLength: NSScreen.main?.frame.width ?? 800 * 0.2)
            #endif

            VStack(alignment: .trailing, spacing: 4) {
                // Message text
                Text(message.text)
                    .font(.system(size: theme.fontBody).leading(.tight))
                    .foregroundStyle(theme.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Inline metadata: "You" label + timestamp
                HStack(spacing: 6) {
                    Text("You")
                        .font(.system(size: 10, weight: .semibold).leading(.tight))
                        .foregroundStyle(theme.accent)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    if let timestamp = message.timestamp {
                        Text(formattedTimestamp(timestamp))
                            .font(.system(size: 10, design: .monospaced).leading(.tight))
                            .foregroundStyle(theme.textTertiary)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(theme.borderSubtle)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .contextMenu {
            Button {
                #if os(iOS)
                UIPasteboard.general.string = message.text
                #else
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message.text, forType: .string)
                #endif
                showCopyConfirmation = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    showCopyConfirmation = false
                }
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            if let onDelete {
                Button(role: .destructive) {
                    onDelete(message)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if showCopyConfirmation {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.success)
                    Text("Copied")
                        .font(.system(size: theme.fontCaption))
                        .foregroundStyle(theme.success)
                }
                .padding(.horizontal, theme.spacingSM)
                .padding(.vertical, theme.spacingXS)
                .background(theme.success.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                .padding(theme.spacingSM)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .accessibilityLabel("You said: \(message.text)")
    }

    private func formattedTimestamp(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return DateFormatters.time.string(from: date)
        } else {
            return DateFormatters.dateTime.string(from: date)
        }
    }
}
