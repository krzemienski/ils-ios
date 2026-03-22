import SwiftUI
import ILSShared

/// Modal sheet for bookmarking a specific chat message with an optional note and tags.
///
/// Displays a preview of the message content, a free-form note field, and a chip-style
/// tag picker sourced from ``BookmarkTagsManager``. Tapping **Save** calls
/// ``MessageBookmarksManager/addBookmark(messageId:sessionId:sessionName:messageContent:messageRole:note:tags:)``
/// and dismisses. Tapping **Cancel** dismisses without saving.
///
/// ## Topics
/// ### Required Inputs
/// - ``messageId`` — The ID of the message being bookmarked.
/// - ``sessionId`` — The session the message belongs to.
///
/// ### Optional Inputs
/// - ``sessionName`` — Display name of the session (shown in the sheet).
/// - ``messageContent`` — Snippet of the message shown in the preview card.
/// - ``messageRole`` — Role string (``"user"`` or ``"assistant"``) used for role label.
struct BookmarkMessageSheet: View {
    // MARK: - Inputs

    let messageId: String
    let sessionId: UUID
    var sessionName: String? = nil
    var messageContent: String? = nil
    var messageRole: String? = nil

    // MARK: - Environment

    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.dismiss) private var dismiss

    // MARK: - Managers

    private let bookmarksManager = MessageBookmarksManager.shared
    private let tagsManager = BookmarkTagsManager.shared

    // MARK: - Local State

    @State private var note: String = ""
    @State private var selectedTagIds: Set<UUID> = []
    @State private var isSaving = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                messagePreviewSection
                noteSection
                tagsSection
            }
            .scrollContentBackground(.hidden)
            .background(theme.bgPrimary)
            .tint(theme.accent)
            .navigationTitle("Bookmark Message")
            #if os(iOS)
            .inlineNavigationBarTitle()
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(theme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(theme.accent)
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                                .foregroundColor(theme.accent)
                        }
                    }
                    .disabled(isSaving)
                    .accessibilityLabel("Save bookmark")
                }
            }
        }
    }

    // MARK: - Sections

    /// Shows a card preview of the message content and its role label.
    private var messagePreviewSection: some View {
        Section("Message") {
            VStack(alignment: .leading, spacing: 8) {
                if let role = messageRole {
                    Text(role.capitalized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(roleColor(for: role))
                }

                if let content = messageContent, !content.isEmpty {
                    Text(content)
                        .font(.subheadline)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(5)
                        .truncationMode(.tail)
                } else {
                    Text("No preview available")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                        .italic()
                }

                if let name = sessionName, !name.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.caption2)
                        Text(name)
                            .font(.caption)
                    }
                    .foregroundStyle(theme.textSecondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    /// A text editor for entering an optional free-form note.
    private var noteSection: some View {
        Section("Note (optional)") {
            TextEditor(text: $note)
                .frame(minHeight: 72)
                .font(.system(.body, design: theme.fontDesign))
                .foregroundColor(theme.textPrimary)
                .scrollContentBackground(.hidden)
                .accessibilityLabel("Bookmark note")
        }
    }

    /// Horizontally scrolling chip row for selecting one or more tags.
    private var tagsSection: some View {
        Section("Tags") {
            if tagsManager.allTags.isEmpty {
                Text("No tags available")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tagsManager.allTags) { tag in
                            tagChip(tag)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Subviews

    private func tagChip(_ tag: BookmarkTag) -> some View {
        let isSelected = selectedTagIds.contains(tag.id)
        let chipColor = Color(hex: tag.colorHex)

        return Button {
            if isSelected {
                selectedTagIds.remove(tag.id)
            } else {
                selectedTagIds.insert(tag.id)
            }
        } label: {
            HStack(spacing: 5) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                }
                Text(tag.name)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? .white : chipColor)
            .background(isSelected ? chipColor : chipColor.opacity(0.12), in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(chipColor.opacity(isSelected ? 0 : 0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(tag.name) tag")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Actions

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let selectedTags = tagsManager.allTags
            .filter { selectedTagIds.contains($0.id) }
            .map(\.name)

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        await bookmarksManager.addBookmark(
            messageId: messageId,
            sessionId: sessionId,
            sessionName: sessionName,
            messageContent: messageContent,
            messageRole: messageRole,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            tags: selectedTags
        )

        dismiss()
    }

    // MARK: - Helpers

    private func roleColor(for role: String) -> Color {
        switch role.lowercased() {
        case "assistant": return theme.accent
        case "user": return theme.textSecondary
        default: return theme.textSecondary
        }
    }
}
