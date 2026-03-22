import SwiftUI
import ILSShared

/// Sheet for resolving sync conflicts between local and server session versions.
///
/// Presented when the user taps a session with `.conflict` sync status.
/// Shows a side-by-side comparison of conflicting fields (name, status,
/// messageCount, lastActiveAt) and provides three resolution options:
/// **Keep Local**, **Use Server**, or **Keep Newest** (auto-resolve by timestamp).
///
/// On selection, calls ``ConflictResolver/resolveConflict(sessionId:resolution:)``
/// and dismisses the sheet.
///
/// ## Topics
/// ### Properties
/// - ``localSession`` — The locally cached version of the session
/// - ``serverSession`` — The server's version of the session
/// - ``conflictFields`` — Fields that differ between the two versions
///
/// ### Resolution
/// - ``resolveKeepLocal()`` — Discards server changes
/// - ``resolveKeepServer()`` — Accepts server version
/// - ``resolveKeepNewest()`` — Auto-resolves using `lastActiveAt` timestamp
struct ConflictResolutionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// The locally cached version of the session.
    let localSession: ChatSession

    /// The server's version of the session.
    let serverSession: ChatSession

    /// Fields that differ between local and server versions.
    let conflictFields: [ConflictField]

    // MARK: - State

    @State private var isResolving = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingLG) {
                headerSection

                comparisonSection

                resolutionSection
            }
            .padding(theme.spacingMD)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Resolve Conflict")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        #if os(iOS)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(theme.bgPrimary, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        #endif
        .disabled(isResolving)
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: theme.spacingSM) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(theme.warning)

            Text("Sync Conflict Detected")
                .font(.system(size: theme.fontTitle3, weight: .bold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Text("This session was modified both locally and on the server. Choose which version to keep.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacingSM)
    }

    // MARK: - Comparison

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Field Comparison")

            VStack(spacing: 0) {
                // Header row
                HStack {
                    Text("Field")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Local")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Server")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .padding(theme.spacingSM)

                Divider().background(theme.bgTertiary)

                // Name row
                comparisonRow(
                    field: "Name",
                    localValue: localSession.name ?? "Untitled",
                    serverValue: serverSession.name ?? "Untitled",
                    hasConflict: conflictFields.contains(.name)
                )

                Divider().background(theme.bgTertiary)

                // Status row
                comparisonRow(
                    field: "Status",
                    localValue: localSession.status.rawValue,
                    serverValue: serverSession.status.rawValue,
                    hasConflict: conflictFields.contains(.status)
                )

                Divider().background(theme.bgTertiary)

                // Message count row
                comparisonRow(
                    field: "Messages",
                    localValue: "\(localSession.messageCount)",
                    serverValue: "\(serverSession.messageCount)",
                    hasConflict: conflictFields.contains(.messageCount)
                )

                Divider().background(theme.bgTertiary)

                // Last active row
                comparisonRow(
                    field: "Last Active",
                    localValue: formattedDate(localSession.lastActiveAt),
                    serverValue: formattedDate(serverSession.lastActiveAt),
                    hasConflict: false
                )
            }
            .modifier(GlassCard(padding: 0))
        }
    }

    // MARK: - Resolution Buttons

    private var resolutionSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Resolution")

            VStack(spacing: theme.spacingSM) {
                resolutionButton(
                    title: "Keep Local Changes",
                    subtitle: "Discard server changes and keep your local version",
                    icon: "iphone",
                    color: theme.accent
                ) {
                    resolveKeepLocal()
                }

                resolutionButton(
                    title: "Use Server Version",
                    subtitle: "Discard local changes and accept the server version",
                    icon: "cloud",
                    color: theme.info
                ) {
                    resolveKeepServer()
                }

                resolutionButton(
                    title: "Keep Newest",
                    subtitle: "Auto-resolve by keeping the most recently active version",
                    icon: "clock.arrow.circlepath",
                    color: theme.success
                ) {
                    resolveKeepNewest()
                }
            }
        }
    }

    // MARK: - Sub-Views

    @ViewBuilder
    private func comparisonRow(
        field: String,
        localValue: String,
        serverValue: String,
        hasConflict: Bool
    ) -> some View {
        HStack {
            HStack(spacing: 4) {
                if hasConflict {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: theme.fontCaption))
                        .foregroundStyle(theme.warning)
                }
                Text(field)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(localValue)
                .foregroundStyle(hasConflict ? theme.warning : theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(serverValue)
                .foregroundStyle(hasConflict ? theme.info : theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
        .foregroundStyle(theme.textPrimary)
        .padding(theme.spacingSM)
    }

    @ViewBuilder
    private func resolutionButton(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer()

                if isResolving {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: theme.fontCaption))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            .padding(theme.spacingMD)
        }
        .modifier(GlassCard(padding: 0))
        .accessibilityLabel(title)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
            .kerning(1)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Resolution Actions

    private func resolveKeepLocal() {
        isResolving = true
        Task {
            await ConflictResolver.shared.resolveConflict(
                sessionId: localSession.id,
                resolution: .keepLocal
            )
            await MainActor.run {
                dismiss()
            }
        }
    }

    private func resolveKeepServer() {
        isResolving = true
        Task {
            await ConflictResolver.shared.resolveConflict(
                sessionId: localSession.id,
                resolution: .keepServer
            )
            await MainActor.run {
                dismiss()
            }
        }
    }

    private func resolveKeepNewest() {
        isResolving = true
        let resolution: ConflictResolution = localSession.lastActiveAt >= serverSession.lastActiveAt
            ? .keepLocal
            : .keepServer

        // If newest is a merge of specific fields, use merge; otherwise use the winning side
        Task {
            await ConflictResolver.shared.resolveConflict(
                sessionId: localSession.id,
                resolution: resolution
            )
            await MainActor.run {
                dismiss()
            }
        }
    }
}
