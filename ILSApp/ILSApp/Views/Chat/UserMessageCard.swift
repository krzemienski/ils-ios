import SwiftUI

/// Full-width user message card with themed styling.
/// NOT a bubble — uses bgSecondary background with cornerRadius.
struct UserMessageCard: View {
    let message: ChatMessage
    var onDelete: ((ChatMessage) -> Void)?

    @Environment(\.theme) private var theme: any AppTheme
    @State private var showCopyConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            // Role indicator
            HStack(spacing: theme.spacingXS) {
                Image(systemName: "person.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.accent)
                Text("You")
                    .font(.system(size: theme.fontCaption, weight: .semibold))
                    .foregroundStyle(theme.accent)
                Spacer()
                if let timestamp = message.timestamp {
                    Text(formattedTimestamp(timestamp))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            // Message text
            Text(message.text)
                .font(.system(size: theme.fontBody))
                .foregroundStyle(theme.textPrimary)
                .textSelection(.enabled)
        }
        .padding(theme.spacingMD)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .strokeBorder(theme.borderSubtle, lineWidth: 0.5)
        )
        .contextMenu {
            Button {
                UIPasteboard.general.string = message.text
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
