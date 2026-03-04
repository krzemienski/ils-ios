import SwiftUI

/// Sheet view for managing persistent session memory notes.
///
/// Displays a list of ``SessionMemoryNote`` values attached to a given session,
/// each showing its title, content preview, and creation date. Users can add
/// new notes via an "Add Note" toolbar button and delete existing ones with
/// swipe-to-delete. An empty state illustration is shown when no notes exist.
///
/// Notes survive context compaction events, giving users a reliable way to
/// preserve key decisions, file paths, and variable names across the full
/// session lifecycle.
///
/// ## Topics
/// ### State
/// - ``sessionId`` - The session whose notes are displayed
/// - ``notes`` - Live-updated array of session memory notes
/// - ``showAddNote`` - Controls presentation of the add-note form
struct SessionMemoryView: View {
    /// The session whose memory notes are shown.
    let sessionId: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot

    @State private var notes: [SessionMemoryNote] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAddNote = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(message: error)
                } else if notes.isEmpty {
                    emptyStateView
                } else {
                    notesList
                }
            }
            .background(theme.bgPrimary)
            .navigationTitle("Session Memory")
            #if os(iOS)
            .inlineNavigationBarTitle()
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(theme.accent)
                        .accessibilityLabel("Done managing session memory")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddNote = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .foregroundColor(theme.accent)
                    .accessibilityLabel("Add new memory note")
                }
            }
            .sheet(isPresented: $showAddNote, onDismiss: {
                Task { await loadNotes() }
            }) {
                AddNoteSheet(sessionId: sessionId)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task { await loadNotes() }
    }

    // MARK: - Notes List

    /// Scrollable list of memory notes with swipe-to-delete.
    private var notesList: some View {
        List {
            Section {
                ForEach(notes) { note in
                    NoteRow(note: note, theme: theme)
                        .listRowBackground(theme.bgSecondary)
                        .listRowSeparatorTint(theme.divider)
                }
                .onDelete { indexSet in
                    Task { await deleteNotes(at: indexSet) }
                }
            } header: {
                HStack {
                    Text("Notes")
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                    Spacer()
                    Text("\(notes.count)")
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.bgTertiary)
                        .clipShape(Capsule())
                        .accessibilityLabel("\(notes.count) notes")
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: theme.spacingMD) {
            ProgressView()
                .tint(theme.accent)
            Text("Loading notes...")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    /// Placeholder shown when no notes have been added yet.
    private var emptyStateView: some View {
        VStack(spacing: theme.spacingLG) {
            Spacer()

            Image(systemName: "note.text")
                .font(.system(size: 48))
                .foregroundStyle(theme.textTertiary)

            VStack(spacing: theme.spacingXS) {
                Text("No Memory Notes")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Text("Save key decisions, file paths, and variable names that survive context compaction.")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, theme.spacingXL)
            }

            Button {
                showAddNote = true
            } label: {
                Label("Add First Note", systemImage: "plus")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .padding(.horizontal, theme.spacingLG)
                    .padding(.vertical, theme.spacingSM)
                    .background(theme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add your first memory note")

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(theme.warning)
            Text("Failed to load notes")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
            Text(message)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
            Button("Retry") {
                Task { await loadNotes() }
            }
            .foregroundColor(theme.accent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Data Operations

    private func loadNotes() async {
        isLoading = true
        errorMessage = nil
        do {
            notes = try await SessionMemoryService.shared.fetchNotes(forSession: sessionId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func deleteNotes(at indexSet: IndexSet) async {
        let toDelete = indexSet.map { notes[$0] }
        do {
            for note in toDelete {
                try await SessionMemoryService.shared.deleteNote(id: note.id)
            }
            notes.remove(atOffsets: indexSet)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Note Row

/// A single row displaying a memory note's title, content preview, and date.
private struct NoteRow: View {
    let note: SessionMemoryNote
    let theme: ThemeSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack {
                Text(note.title)
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text(note.createdAt, style: .date)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }

            if !note.content.isEmpty {
                Text(note.content)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(3)
            }

            if !note.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: theme.spacingXS) {
                        ForEach(note.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(theme.accent.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.vertical, theme.spacingXS)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(note.title). \(note.content). Created \(note.createdAt.formatted())")
    }
}

// MARK: - Add Note Sheet

/// Modal form for creating a new session memory note.
///
/// Provides title and content text fields with validation. Submits via the
/// ``SessionMemoryService`` actor and dismisses on success.
private struct AddNoteSheet: View {
    let sessionId: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot

    @State private var title = ""
    @State private var content = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .accessibilityLabel("Note title")
                } header: {
                    Text("Title")
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                }

                Section {
                    TextEditor(text: $content)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .frame(minHeight: 120)
                        .accessibilityLabel("Note content")
                } header: {
                    Text("Content")
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                } footer: {
                    Text("Capture key decisions, file paths, or variable names you want Claude to remember after compaction.")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                }

                if let error = errorMessage {
                    Section {
                        HStack(spacing: theme.spacingSM) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(theme.error)
                            Text(error)
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                .foregroundStyle(theme.error)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.bgPrimary)
            .navigationTitle("New Note")
            #if os(iOS)
            .inlineNavigationBarTitle()
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(theme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button("Save") {
                            Task { await saveNote() }
                        }
                        .foregroundColor(theme.accent)
                        .disabled(!canSave)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func saveNote() async {
        isSaving = true
        errorMessage = nil
        do {
            try await SessionMemoryService.shared.saveNote(
                sessionId: sessionId,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                content: content.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}

// MARK: - Preview

#Preview("With Notes") {
    SessionMemoryView(sessionId: UUID())
}

#Preview("Empty State") {
    SessionMemoryView(sessionId: UUID())
}
