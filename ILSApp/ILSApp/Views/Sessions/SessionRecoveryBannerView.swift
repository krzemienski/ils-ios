import SwiftUI
import ILSShared

/// A compact banner surfaced when one or more sessions are eligible for recovery.
///
/// The banner displays when `recoverableSessions` is non-empty and provides two
/// primary actions:
///
/// - **Review** — opens ``RecoveryTimelineView`` as a sheet so the user can browse
///   checkpoints and restore the interrupted session.
/// - **Dismiss** (×) — for a single session, calls `dismissSession` immediately;
///   for multiple sessions, presents a picker sheet so the user can choose which
///   session to suppress.
///
/// The banner animates in from the top with a combined move + opacity transition
/// and uses `theme.warning` as its accent colour to convey urgency without alarm.
///
/// ## Usage
/// ```swift
/// if !recoveryViewModel.recoverableSessions.isEmpty {
///     SessionRecoveryBannerView(viewModel: recoveryViewModel)
///         .transition(.move(edge: .top).combined(with: .opacity))
/// }
/// ```
struct SessionRecoveryBannerView: View {
    @Bindable var viewModel: SessionRecoveryViewModel
    var onRestored: ((ChatSession) -> Void)?

    @Environment(\.theme) private var theme: ThemeSnapshot

    // MARK: - Sheet state

    /// Controls the ``RecoveryTimelineView`` sheet.
    @State private var showTimeline = false

    /// The session selected for timeline review.
    @State private var selectedSession: ChatSession?

    /// Controls the multi-session dismiss picker sheet.
    @State private var showDismissPicker = false

    // MARK: - Body

    var body: some View {
        HStack(spacing: 10) {
            // Warning icon
            Image(systemName: "exclamationmark.arrow.circlepath")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.warning)

            // Label
            Text(bannerLabel)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 4)

            // Review button
            Button {
                selectedSession = viewModel.recoverableSessions.first
                showTimeline = true
            } label: {
                Text("Review")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.warning)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(theme.warning.opacity(0.15), in: Capsule())
            }
            .buttonStyle(.plain)

            // Dismiss button
            Button {
                handleDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .padding(6)
                    .background(theme.bgSecondary, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(theme.warning.opacity(0.10))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(theme.warning.opacity(0.25)),
            alignment: .bottom
        )
        // MARK: Review sheet
        .sheet(isPresented: $showTimeline) {
            if let session = selectedSession {
                NavigationStack {
                    RecoveryTimelineView(session: session) { restored in
                        Task { await viewModel.dismissSession(session) }
                        onRestored?(restored)
                    }
                }
            }
        }
        // MARK: Multi-session dismiss picker sheet
        .sheet(isPresented: $showDismissPicker) {
            dismissPickerSheet
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Helpers

    /// Banner label copy, adapting to the count of recoverable sessions.
    private var bannerLabel: String {
        let count = viewModel.recoverableSessions.count
        if count == 1 {
            return "1 session interrupted — tap to recover"
        }
        return "\(count) sessions interrupted — tap to recover"
    }

    /// Handles the × dismiss button: immediate dismiss for a single session,
    /// picker sheet for multiple sessions.
    private func handleDismiss() {
        if viewModel.recoverableSessions.count == 1,
           let single = viewModel.recoverableSessions.first {
            Task { await viewModel.dismissSession(single) }
        } else {
            showDismissPicker = true
        }
    }

    // MARK: - Dismiss picker sheet

    private var dismissPickerSheet: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(viewModel.recoverableSessions) { session in
                        Button {
                            showDismissPicker = false
                            Task { await viewModel.dismissSession(session) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.circle")
                                    .font(.system(size: 16))
                                    .foregroundStyle(theme.warning)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.displayName)
                                        .font(.body)
                                        .foregroundStyle(theme.textPrimary)
                                        .lineLimit(1)

                                    Text(session.lastActiveAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(theme.textSecondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Dismiss recovery for a session")
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.bgPrimary)
            .navigationTitle("Dismiss Session")
            #if os(iOS)
            .inlineNavigationBarTitle()
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cancel") { showDismissPicker = false }
                }
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Single session") {
    let vm = SessionRecoveryViewModel()
    return VStack(spacing: 0) {
        SessionRecoveryBannerView(viewModel: vm)
        Spacer()
    }
}
#endif
