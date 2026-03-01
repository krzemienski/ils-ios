import SwiftUI
import ILSShared

// MARK: - SessionPickerView

/// Sheet for selecting two sessions to compare side-by-side.
///
/// Presents a searchable list of sessions with checkmarks for selecting
/// Session A and Session B. A "Recently Compared" section at the top
/// allows quick re-selection of past pairs.
///
/// ## Topics
/// ### Parameters
/// - ``sessions`` - All available sessions to pick from
/// - ``recentlyCompared`` - Recently compared pairs for quick shortcuts
/// - ``preselectedSession`` - Optional pre-selected session A (e.g., from context menu)
/// - ``onCompare`` - Invoked with the two selected sessions when Compare is tapped
struct SessionPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot

    // MARK: - Parameters

    let sessions: [ChatSession]
    let recentlyCompared: [RecentlyComparedPair]
    let preselectedSession: ChatSession?
    let onCompare: (ChatSession, ChatSession) -> Void

    // MARK: - State

    @State private var selectedA: ChatSession?
    @State private var selectedB: ChatSession?
    @State private var searchText: String = ""

    @FocusState private var isSearchFocused: Bool

    // MARK: - Computed

    private var filteredSessions: [ChatSession] {
        guard !searchText.isEmpty else { return sessions }
        let query = searchText.lowercased()
        return sessions.filter {
            ($0.name ?? "").lowercased().contains(query)
                || ($0.projectName ?? "").lowercased().contains(query)
                || $0.model.lowercased().contains(query)
        }
    }

    private var canCompare: Bool {
        selectedA != nil && selectedB != nil && selectedA?.id != selectedB?.id
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, theme.spacingMD)
                .padding(.top, theme.spacingSM)
                .padding(.bottom, theme.spacingSM)

            Divider().overlay(theme.divider)

            ScrollView {
                LazyVStack(spacing: theme.spacingMD, pinnedViews: []) {
                    if !recentlyCompared.isEmpty && searchText.isEmpty {
                        recentlyComparedSection
                    }

                    sessionASection

                    sessionBSection
                }
                .padding(.horizontal, theme.spacingMD)
                .padding(.vertical, theme.spacingSM)
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle("Select Sessions")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(theme.textSecondary)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Compare") {
                    guard let a = selectedA, let b = selectedB else { return }
                    onCompare(a, b)
                    dismiss()
                }
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(canCompare ? theme.accent : theme.textTertiary)
                .disabled(!canCompare)
                .accessibilityIdentifier("compare-button")
            }
        }
        #if os(iOS)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        #endif
        .onAppear {
            selectedA = preselectedSession
        }
    }

    // MARK: - Search Bar

    @ViewBuilder
    private var searchBar: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
            TextField("Search sessions...", text: $searchText)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .focused($isSearchFocused)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, theme.spacingXS + 2)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .accessibilityIdentifier("session-search")
    }

    // MARK: - Recently Compared Section

    @ViewBuilder
    private var recentlyComparedSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Recently Compared")

            LazyVStack(spacing: 2) {
                ForEach(recentlyCompared) { pair in
                    recentlyComparedRow(pair)
                }
            }
        }
        .accessibilityIdentifier("recently-compared-section")
    }

    @ViewBuilder
    private func recentlyComparedRow(_ pair: RecentlyComparedPair) -> some View {
        let nameA = pair.sessionAName ?? "Session \(pair.sessionAId.uuidString.prefix(8))"
        let nameB = pair.sessionBName ?? "Session \(pair.sessionBId.uuidString.prefix(8))"

        Button {
            // Quick-select: find the sessions by ID in the sessions list
            let a = sessions.first { $0.id == pair.sessionAId }
            let b = sessions.first { $0.id == pair.sessionBId }
            if let a, let b {
                selectedA = a
                selectedB = b
            }
        } label: {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: theme.spacingXS) {
                        Text(nameA)
                            .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(1)
                        Text("vs")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                        Text(nameB)
                            .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(1)
                    }
                    Text(relativeDate(pair.comparedAt))
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(theme.spacingSM)
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            .contentShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(nameA) vs \(nameB)")
    }

    // MARK: - Session A Section

    @ViewBuilder
    private var sessionASection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack {
                sectionLabel("Session A")
                if let a = selectedA {
                    Spacer()
                    Text(a.displayName)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.accent)
                        .lineLimit(1)
                        .transition(.opacity)
                }
            }

            if filteredSessions.isEmpty {
                noResultsView(text: "No matching sessions")
            } else {
                LazyVStack(spacing: 2) {
                    ForEach(filteredSessions) { session in
                        sessionRow(session, slot: .a)
                    }
                }
            }
        }
        .accessibilityIdentifier("session-a-section")
    }

    // MARK: - Session B Section

    @ViewBuilder
    private var sessionBSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack {
                sectionLabel("Session B")
                if let b = selectedB {
                    Spacer()
                    Text(b.displayName)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.accent)
                        .lineLimit(1)
                        .transition(.opacity)
                }
            }

            if filteredSessions.isEmpty {
                noResultsView(text: "No matching sessions")
            } else {
                LazyVStack(spacing: 2) {
                    ForEach(filteredSessions) { session in
                        sessionRow(session, slot: .b)
                    }
                }
            }
        }
        .accessibilityIdentifier("session-b-section")
    }

    // MARK: - Session Row

    private enum SessionSlot { case a, b }

    @ViewBuilder
    private func sessionRow(_ session: ChatSession, slot: SessionSlot) -> some View {
        let isSelected: Bool = slot == .a
            ? selectedA?.id == session.id
            : selectedB?.id == session.id
        let isSameAsOther: Bool = slot == .a
            ? selectedB?.id == session.id
            : selectedA?.id == session.id

        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                switch slot {
                case .a: selectedA = session
                case .b: selectedB = session
                }
            }
        } label: {
            HStack(spacing: theme.spacingSM) {
                Circle()
                    .fill(session.status == .active ? theme.success : theme.textTertiary.opacity(0.3))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.displayName)
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(isSameAsOther ? theme.textTertiary : theme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: theme.spacingXS) {
                        if let projectName = session.projectName {
                            Text(projectName)
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.entityProject)
                        }

                        Text(session.model.capitalized)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.entitySession)

                        Text("\u{00b7}")
                            .foregroundStyle(theme.textTertiary)

                        Text("\(session.messageCount) msgs")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                }

                Spacer()

                if isSameAsOther {
                    // Session already chosen as the other slot
                    Image(systemName: "minus.circle")
                        .foregroundStyle(theme.textTertiary)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.accent)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                }
            }
            .padding(theme.spacingSM)
            .background(
                isSelected
                    ? theme.accent.opacity(0.08)
                    : (isSameAsOther ? theme.bgTertiary : theme.bgSecondary)
            )
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            .contentShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .buttonStyle(.plain)
        .disabled(isSameAsOther)
        .accessibilityLabel("\(session.displayName), \(session.model), \(session.messageCount) messages")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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

    @ViewBuilder
    private func noResultsView(text: String) -> some View {
        VStack(spacing: theme.spacingSM) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
            Text(text)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacingLG)
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview {
    SessionPickerView(
        sessions: [],
        recentlyCompared: [],
        preselectedSession: nil,
        onCompare: { _, _ in }
    )
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
