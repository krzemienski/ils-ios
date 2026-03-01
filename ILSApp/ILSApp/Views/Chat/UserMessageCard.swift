import SwiftUI
import ILSShared

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
        lhs.message.text == rhs.message.text &&
        lhs.message.attachments == rhs.message.attachments
    }

    @Environment(\.theme) private var theme: ThemeSnapshot
    @State private var showCopyConfirmation = false

    var body: some View {
        HStack {
            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4) {
                // Attachment previews (shown above text when present)
                if !message.attachments.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(message.attachments, id: \.id) { attachment in
                            attachmentView(for: attachment)
                        }
                    }
                }

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

            // Copy Image — one menu item per image attachment
            ForEach(message.attachments.filter { $0.mimeType.hasPrefix("image/") }, id: \.id) { attachment in
                Button {
                    copyImage(attachment)
                } label: {
                    Label(
                        message.attachments.filter { $0.mimeType.hasPrefix("image/") }.count > 1
                            ? "Copy Image \(message.attachments.firstIndex(where: { $0.id == attachment.id }).map { $0 + 1 }.map(String.init) ?? "")"
                            : "Copy Image",
                        systemImage: "photo.on.rectangle"
                    )
                }
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

    // MARK: - Attachment helpers

    @ViewBuilder
    private func attachmentView(for attachment: MessageAttachment) -> some View {
        if attachment.mimeType.hasPrefix("image/") {
            if let image = makeImage(from: attachment) {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            HStack(spacing: 6) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(theme.accent)
                Text(attachment.filename ?? "Attachment")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func makeImage(from attachment: MessageAttachment) -> Image? {
        guard let data = Data(base64Encoded: attachment.data) else { return nil }
        #if os(iOS)
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
        #elseif os(macOS)
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
        #endif
    }

    private func copyImage(_ attachment: MessageAttachment) {
        guard let data = Data(base64Encoded: attachment.data) else { return }
        #if os(iOS)
        if let image = UIImage(data: data) {
            UIPasteboard.general.image = image
        }
        #elseif os(macOS)
        if let image = NSImage(data: data) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([image])
        }
        #endif
    }

    private func formattedTimestamp(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return DateFormatters.time.string(from: date)
        } else {
            return DateFormatters.dateTime.string(from: date)
        }
    }
}
