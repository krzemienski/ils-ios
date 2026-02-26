import SwiftUI

/// Compact right-aligned bubble displaying a user-authored message with an inline delete action.
///
/// Renders the message text left-aligned within a right-floated pill that uses `theme.borderSubtle`
/// as its surface color. A "You" label (accent-colored, semibold) and a formatted timestamp appear
/// below the text at caption size. The containing `HStack` pushes the card to the trailing edge via
/// a leading `Spacer`; visual width is bounded by the parent caller's horizontal padding.
///
/// A long-press context menu exposes Copy and (when `onDelete` is provided) a destructive Delete
/// action. Copying writes to the platform clipboard and triggers a transient "Copied" overlay that
/// auto-dismisses after two seconds, rendered with a `.scale.combined(with: .opacity)` transition.
///
/// ## Topics
/// ### Input Properties
/// - ``message`` - The user `ChatMessage` whose text and timestamp are displayed
///
/// ### Callbacks
/// - ``onDelete`` - Optional closure called with the message when the user selects "Delete"
///   from the context menu; omit to hide the delete option
struct UserMessageCard: View, Equatable {
    /// The user message to display, including its text, optional timestamp, and identity.
    let message: ChatMessage
    /// Called with the message when the user selects "Delete" from the context menu.
    /// When `nil`, the delete option is omitted from the menu.
    var onDelete: ((ChatMessage) -> Void)?

    static func == (lhs: UserMessageCard, rhs: UserMessageCard) -> Bool {
        lhs.message.id == rhs.message.id &&
        lhs.message.text == rhs.message.text
    }

    @Environment(\.theme) private var theme: ThemeSnapshot
    @State private var showCopyConfirmation = false

    var body: some View {
        HStack {
            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4) {
                // Message text
                Text(message.text)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign).leading(.tight))
                    .foregroundStyle(theme.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Inline metadata: "You" label + timestamp
                HStack(spacing: 6) {
                    Text("You")
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign).leading(.tight))
                        .foregroundStyle(theme.accent)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    if let timestamp = message.timestamp {
                        Text(formattedTimestamp(timestamp))
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign).leading(.tight))
                            .foregroundStyle(theme.textTertiary)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(theme.borderSubtle)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
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
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
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
