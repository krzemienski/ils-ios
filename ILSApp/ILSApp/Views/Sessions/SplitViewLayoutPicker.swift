import SwiftUI
import ILSShared

/// Sheet for configuring the split view layout and which sessions appear in each pane.
///
/// Presents two sections:
/// 1. **Layout** — HStack of bordered buttons for selecting 2, 3, or 4 panes.
/// 2. **Sessions** — Scrollable list of all sessions with checkbox-style pin toggles.
///    Up to ``SplitViewLayout/paneCount`` sessions may be pinned at once.
///
/// Displayed as a `.sheet` from the ``MultiSessionSplitView`` toolbar.
struct SplitViewLayoutPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// View model holding layout selection and pinned session IDs.
    var multiSessionVM: MultiSessionViewModel
    /// View model providing the full session list.
    var sessionsVM: SessionsViewModel

    var body: some View {
        NavigationStack {
            List {
                layoutSection
                sessionsSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(theme.bgPrimary)
            .tint(theme.accent)
            .navigationTitle("Configure Split View")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(theme.accent)
                        .accessibilityLabel("Done configuring split view")
                }
            }
        }
    }

    // MARK: - Layout Selector

    /// HStack of bordered buttons for choosing between 2, 3, and 4-pane layouts.
    private var layoutSection: some View {
        Section("Layout") {
            HStack(spacing: theme.spacingSM) {
                ForEach(SplitViewLayout.allCases, id: \.self) { layout in
                    let isSelected = multiSessionVM.selectedLayout == layout
                    Button {
                        HapticManager.selection()
                        multiSessionVM.selectedLayout = layout
                    } label: {
                        Text(layout.displayName)
                            .font(.system(
                                size: theme.fontCaption,
                                weight: isSelected ? .semibold : .regular,
                                design: theme.fontDesign
                            ))
                            .foregroundStyle(isSelected ? theme.textOnAccent : theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, theme.spacingSM)
                            .background(
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                                    .fill(isSelected ? theme.accent : theme.bgTertiary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                                    .stroke(isSelected ? theme.accent : theme.divider, lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(layout.displayName) layout")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    // MARK: - Session List

    /// List of all sessions with checkbox-style pin indicators.
    ///
    /// Pinning is disabled once the selected layout's pane count is reached.
    private var sessionsSection: some View {
        let maxPins = multiSessionVM.selectedLayout.paneCount
        let pinnedCount = multiSessionVM.pinnedSessionIds.count

        return Section {
            ForEach(sessionsVM.sessions) { session in
                sessionRow(
                    session: session,
                    pinnedCount: pinnedCount,
                    maxPins: maxPins
                )
            }
        } header: {
            Text("Sessions (max \(maxPins))")
        } footer: {
            if pinnedCount > maxPins {
                Text("Reduce pinned sessions to match the selected layout.")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
        }
    }

    /// A single row for a session in the pin list.
    ///
    /// Shows a filled checkmark when pinned, an empty circle when not.
    /// Disables the button when unpinned and at the layout max, preventing over-pinning.
    @ViewBuilder
    private func sessionRow(
        session: ChatSession,
        pinnedCount: Int,
        maxPins: Int
    ) -> some View {
        let isPinned = multiSessionVM.isPinned(session)
        let atMax = pinnedCount >= maxPins && !isPinned

        Button {
            HapticManager.selection()
            if isPinned {
                multiSessionVM.unpinSession(session)
            } else {
                multiSessionVM.pinSession(session)
            }
        } label: {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: isPinned ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: theme.fontBody + 2, design: theme.fontDesign))
                    .foregroundStyle(isPinned ? theme.accent : theme.textTertiary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.name ?? "Unnamed")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(atMax ? theme.textTertiary : theme.textPrimary)
                        .lineLimit(1)

                    if let project = session.projectName {
                        Text(project)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
        }
        .disabled(atMax)
        .listRowBackground(theme.bgSecondary)
        .accessibilityLabel("\(session.name ?? "Unnamed"), \(isPinned ? "pinned" : "not pinned")")
        .accessibilityHint(atMax ? "Remove a pinned session to pin more" : isPinned ? "Tap to unpin" : "Tap to pin")
        .accessibilityAddTraits(isPinned ? .isSelected : [])
    }
}
