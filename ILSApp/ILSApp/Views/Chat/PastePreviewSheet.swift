import SwiftUI
import ILSShared

/// Modal sheet presenting a preview of detected paste content with formatting options.
///
/// Displays the detected content type (Code, URL, Error Log, File Path), language (for code),
/// and a preview of how the content will be formatted. Provides two action buttons:
/// - **Insert Formatted**: Applies intelligent markdown formatting based on detected type
/// - **Insert Plain Text**: Inserts the raw unformatted text
///
/// ## Topics
/// ### Initialization
/// - ``init(isPresented:detectedContent:originalText:onInsertFormatted:onInsertPlain:)``
///
/// ### Content Display
/// - ``contentTypeHeader``
/// - ``previewSection``
/// - ``actionButtons``
struct PastePreviewSheet: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.dismiss) private var dismiss

    /// Controls visibility of this sheet.
    @Binding var isPresented: Bool

    /// The detected content information (type, confidence, metadata).
    let detectedContent: ContentDetector.DetectionResult

    /// The original pasted text before any formatting.
    let originalText: String

    /// Callback invoked when user taps "Insert Formatted" with the formatted markdown text.
    let onInsertFormatted: (String) -> Void

    /// Callback invoked when user taps "Insert Plain Text" with the original unformatted text.
    let onInsertPlain: (String) -> Void

    /// Detected language for code content (lazily computed).
    private var detectedLanguage: String? {
        guard detectedContent.type == .code else { return nil }
        return LanguageDetector.detect(originalText)?.language
    }

    /// Preview of the formatted content (lazily computed).
    private var formattedPreview: String {
        PasteFormatter.format(originalText, detectionResult: detectedContent)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                contentTypeHeader
                previewSection
                Spacer()
                actionButtons
            }
            .padding()
            .background(theme.bgPrimary)
            .navigationTitle("Smart Paste")
            #if os(iOS)
            .inlineNavigationBarTitle()
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(theme.textSecondary)
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        #endif
    }

    /// Header section displaying the detected content type with icon and metadata.
    private var contentTypeHeader: some View {
        VStack(spacing: 12) {
            // Icon for content type
            Image(systemName: contentTypeIcon)
                .font(.system(size: 48))
                .foregroundColor(theme.accent)
                .accessibilityLabel("\(contentTypeLabel) detected")

            // Content type label
            Text(contentTypeLabel)
                .font(.system(.title2, design: theme.fontDesign, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            // Confidence indicator
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(.caption))
                    .foregroundColor(confidenceColor)
                Text("\(Int(detectedContent.confidence * 100))% confident")
                    .font(.system(.caption, design: theme.fontDesign))
                    .foregroundColor(theme.textSecondary)
            }

            // Language indicator for code
            if let language = detectedLanguage {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(.caption))
                        .foregroundColor(theme.accent)
                    Text(language.capitalized)
                        .font(.system(.caption, design: theme.fontDesign, weight: .medium))
                        .foregroundColor(theme.textPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(theme.accent.opacity(0.1))
                .cornerRadius(theme.cornerRadius)
            }
        }
        .padding(.top, 8)
    }

    /// Preview section showing what the formatted content will look like.
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(.system(.subheadline, design: theme.fontDesign, weight: .semibold))
                .foregroundColor(theme.textSecondary)

            ScrollView {
                Text(previewText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(theme.bgSecondary)
                    .cornerRadius(theme.cornerRadius)
            }
            .frame(maxHeight: 200)
        }
    }

    /// Action buttons for inserting formatted or plain text.
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Primary action: Insert Formatted
            Button {
                onInsertFormatted(formattedPreview)
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "wand.and.stars")
                    Text("Insert Formatted")
                        .font(.system(.body, design: theme.fontDesign, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(theme.accent)
                .foregroundColor(theme.textOnAccent)
                .cornerRadius(theme.cornerRadiusLarge)
            }
            .accessibilityLabel("Insert formatted \(contentTypeLabel.lowercased())")

            // Secondary action: Insert Plain Text
            Button {
                onInsertPlain(originalText)
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "text.alignleft")
                    Text("Insert Plain Text")
                        .font(.system(.body, design: theme.fontDesign))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(theme.bgSecondary)
                .foregroundColor(theme.textPrimary)
                .cornerRadius(theme.cornerRadiusLarge)
            }
            .accessibilityLabel("Insert plain text without formatting")
        }
        .padding(.bottom, 8)
    }

    // MARK: - Computed Properties

    /// SF Symbol icon name for the detected content type.
    private var contentTypeIcon: String {
        switch detectedContent.type {
        case .code:
            return "curlybraces"
        case .url:
            return "link"
        case .filePath:
            return "doc.text"
        case .errorLog:
            return "exclamationmark.triangle"
        case .plainText:
            return "text.alignleft"
        }
    }

    /// Human-readable label for the detected content type.
    private var contentTypeLabel: String {
        switch detectedContent.type {
        case .code:
            return "Code"
        case .url:
            return "URL"
        case .filePath:
            return "File Path"
        case .errorLog:
            return "Error Log"
        case .plainText:
            return "Plain Text"
        }
    }

    /// Color for confidence indicator based on confidence level.
    private var confidenceColor: Color {
        if detectedContent.confidence >= 0.8 {
            return .green
        } else if detectedContent.confidence >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }

    /// Preview text to display (truncated if too long).
    private var previewText: String {
        let maxLength = 500
        if formattedPreview.count > maxLength {
            return String(formattedPreview.prefix(maxLength)) + "\n\n... (truncated)"
        }
        return formattedPreview
    }
}
