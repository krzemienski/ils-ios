import SwiftUI
import ILSShared

/// Horizontal scrolling strip showing thumbnail previews of pending chat attachments.
///
/// Displays a 64×64 card for each attachment:
/// - Image attachments: decoded base64 thumbnail
/// - Non-image attachments: document icon with truncated filename
///
/// Each card has an `xmark.circle.fill` dismiss button at the top-right corner.
struct AttachmentPreviewStrip: View {
    /// Mutable binding to the pending attachments list. Cards update it on removal.
    @Binding var attachments: [MessageAttachment]

    @Environment(\.theme) private var theme: ThemeSnapshot

    private let thumbnailSize: CGFloat = 64

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacingSM) {
                ForEach(attachments, id: \.id) { attachment in
                    thumbnailCard(for: attachment)
                }
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingSM)
        }
        .accessibilityIdentifier("attachment-preview-strip")
    }

    // MARK: - Card

    @ViewBuilder
    private func thumbnailCard(for attachment: MessageAttachment) -> some View {
        ZStack(alignment: .topTrailing) {
            // Thumbnail content
            Group {
                if attachment.mimeType.hasPrefix("image/"),
                   let image = decodedImage(from: attachment.data) {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    documentPlaceholder(for: attachment)
                }
            }
            .frame(width: thumbnailSize, height: thumbnailSize)
            .clipped()
            .cornerRadius(theme.cornerRadiusSmall)
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                    .stroke(theme.divider, lineWidth: 0.5)
            )

            // Remove button
            Button {
                withAnimation(.spring(response: 0.25)) {
                    attachments.removeAll { $0.id == attachment.id }
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: theme.fontTitle3, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.white, Color.black.opacity(0.6))
            }
            .offset(x: 6, y: -6)
            .accessibilityLabel("Remove \(attachment.filename ?? "attachment")")
        }
    }

    // MARK: - Document placeholder

    @ViewBuilder
    private func documentPlaceholder(for attachment: MessageAttachment) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "doc.fill")
                .font(.system(size: theme.fontTitle2))
                .foregroundStyle(theme.accent)

            if let filename = attachment.filename {
                Text(filename)
                    // ACC-007: Use theme caption size for Dynamic Type compliance
                    .font(.system(size: theme.fontCaption, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bgSecondary)
    }

    // MARK: - Helpers

    /// Decodes a base64 string into a SwiftUI `Image` using the appropriate
    /// platform type (`UIImage` on iOS, `NSImage` on macOS).
    private func decodedImage(from base64: String) -> Image? {
        guard let data = Data(base64Encoded: base64) else { return nil }
        #if os(iOS)
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
        #elseif os(macOS)
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
        #endif
    }
}
