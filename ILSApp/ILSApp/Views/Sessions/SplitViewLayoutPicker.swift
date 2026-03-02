import SwiftUI
import ILSShared

/// Sheet for configuring split view layout and pinned sessions.
///
/// Lets the user pick 2/3/4-pane layout and toggle which sessions appear.
///
/// - Note: Full implementation provided by subtask-2-3. This stub satisfies
///   compile-time references from ``MultiSessionSplitView``.
struct SplitViewLayoutPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot

    var multiSessionVM: MultiSessionViewModel
    var sessionsVM: SessionsViewModel

    var body: some View {
        NavigationStack {
            List {
                // Layout selector
                Section("Layout") {
                    HStack(spacing: theme.spacingSM) {
                        ForEach(SplitViewLayout.allCases, id: \.self) { layout in
                            Button {
                                multiSessionVM.selectedLayout = layout
                            } label: {
                                Text(layout.displayName)
                                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                                    .foregroundStyle(multiSessionVM.selectedLayout == layout ? theme.textOnAccent : theme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, theme.spacingXS + 2)
                                    .background(multiSessionVM.selectedLayout == layout ? theme.accent : theme.bgSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                                            .stroke(theme.divider, lineWidth: 0.5)
                                    )
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                // Session pins
                Section("Sessions (max \(multiSessionVM.selectedLayout.paneCount))") {
                    ForEach(sessionsVM.sessions.prefix(50)) { session in
                        let pinned = multiSessionVM.isPinned(session)
                        Button {
                            if pinned {
                                multiSessionVM.unpinSession(session)
                            } else {
                                multiSessionVM.pinSession(session)
                            }
                        } label: {
                            HStack(spacing: theme.spacingSM) {
                                Image(systemName: pinned ? "pin.fill" : "pin")
                                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                    .foregroundStyle(pinned ? theme.accent : theme.textTertiary)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.name ?? "Unnamed")
                                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                        .foregroundStyle(theme.textPrimary)
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
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Configure Split View")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
