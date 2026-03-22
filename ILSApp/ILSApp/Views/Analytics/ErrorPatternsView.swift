import SwiftUI
import ILSShared

/// Dashboard view for AI-powered error pattern detection and auto-fix suggestions.
///
/// Displays the top-10 recurring error patterns for a selected project with
/// occurrence counts, confidence badges, resolution status, and suggested fixes.
/// Follows the same structural conventions as ``AnalyticsView`` — GlassCard
/// containers, shimmer loading skeletons, and an inline error banner with retry.
///
/// ## Topics
/// ### State
/// - ``viewModel`` - Observable view model that owns all data loading
/// - ``selectedPatternID`` - Tracks the expanded pattern row (shows fix list)
///
/// ### Sections
/// - ``projectPicker`` - Menu picker for filtering patterns by project
/// - ``summaryHeader`` - Unresolved-count badge and total patterns count
/// - ``patternList`` - Scrollable list of ``ErrorPatternRow`` cards
/// - ``errorBanner`` - Inline error banner with a Retry action
/// - ``loadingSkeleton`` - Shimmer placeholder shown while loading
/// - ``emptyState`` - Shown when no patterns exist for the selected project
struct ErrorPatternsView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// Observable view model that manages pattern loading and fix application.
    @State private var viewModel = ErrorPatternsViewModel()
    /// ID of the currently expanded pattern row (nil = all collapsed).
    @State private var selectedPatternID: UUID?
    /// Pattern to present in the detail sheet (nil = no sheet).
    @State private var detailPattern: ErrorPattern?

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingMD) {
                // Project filter picker
                projectPicker

                if viewModel.isLoading && viewModel.patterns.isEmpty {
                    // Show shimmer skeleton only on first load
                    loadingSkeleton
                } else {
                    // Inline error banner — shown even when partial data is present
                    errorBanner

                    // Summary header (unresolved count + total)
                    summaryHeader

                    // Pattern rows
                    if viewModel.patterns.isEmpty {
                        emptyState
                    } else {
                        patternList
                    }
                }
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.bottom, theme.spacingLG)
            .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Error Patterns")
        .onAppear {
            viewModel.configure(client: appState.apiClient)
            Task {
                await viewModel.loadPatterns()
            }
        }
        .onChange(of: viewModel.selectedProject) { _, _ in
            Task {
                await viewModel.loadPatterns()
            }
        }
        .sheet(item: $detailPattern) { pattern in
            ErrorPatternDetailView(pattern: pattern, viewModel: viewModel)
        }
    }

    // MARK: - Project Picker

    /// Menu picker that filters error patterns by project name.
    ///
    /// Derives the available project names from the loaded patterns, with an
    /// "All Projects" option that clears the filter (``viewModel.selectedProject == nil``).
    private var projectPicker: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "folder.fill")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.accent)

            Menu {
                Button {
                    viewModel.selectedProject = nil
                } label: {
                    HStack {
                        Text("All Projects")
                        if viewModel.selectedProject == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Divider()

                ForEach(availableProjects, id: \.self) { project in
                    Button {
                        viewModel.selectedProject = project
                    } label: {
                        HStack {
                            Text(project)
                            if viewModel.selectedProject == project {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: theme.spacingXS) {
                    Text(viewModel.selectedProject ?? "All Projects")
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .accessibilityLabel("Filter by project")
            .accessibilityHint("Select a project to show only its error patterns")

            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.8)
                    .accessibilityLabel("Loading error patterns")
            }
        }
        .padding(.vertical, theme.spacingXS)
    }

    // MARK: - Summary Header

    /// High-level stat tiles showing unresolved pattern count and total patterns.
    @ViewBuilder
    private var summaryHeader: some View {
        if !viewModel.patterns.isEmpty {
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: theme.spacingSM
            ) {
                ErrorStatTile(
                    label: "Unresolved",
                    value: "\(viewModel.unresolvedCount)",
                    icon: "exclamationmark.triangle.fill",
                    color: viewModel.unresolvedCount > 0 ? theme.error : theme.success
                )
                ErrorStatTile(
                    label: "Total Patterns",
                    value: "\(viewModel.patterns.count)",
                    icon: "chart.bar.doc.horizontal",
                    color: theme.accent
                )
            }
        }
    }

    // MARK: - Pattern List

    /// Scrollable list of pattern rows, each expandable to show suggested fixes.
    private var patternList: some View {
        VStack(spacing: theme.spacingSM) {
            ForEach(viewModel.patterns) { pattern in
                ErrorPatternRow(
                    pattern: pattern,
                    isExpanded: selectedPatternID == pattern.id,
                    onToggle: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedPatternID = selectedPatternID == pattern.id ? nil : pattern.id
                        }
                    },
                    onViewDetail: {
                        detailPattern = pattern
                    },
                    onResolve: {
                        Task {
                            await viewModel.resolvePattern(pattern)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Error Banner

    /// Inline error banner displayed when ``ErrorPatternsViewModel/error`` is non-nil.
    @ViewBuilder
    private var errorBanner: some View {
        if let error = viewModel.error {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(theme.warning)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Failed to load error patterns")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Text(error.localizedDescription)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Button {
                    Task { await viewModel.retryLoad() }
                } label: {
                    Text("Retry")
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textOnAccent)
                        .padding(.horizontal, theme.spacingSM)
                        .padding(.vertical, theme.spacingXS)
                        .background(theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }
                .accessibilityLabel("Retry loading error patterns")
            }
            .padding(theme.spacingMD)
            .background(theme.warning.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .stroke(theme.warning.opacity(0.3), lineWidth: 0.5)
            )
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Loading Skeleton

    /// Shimmer placeholder shown on first load before any patterns arrive.
    private var loadingSkeleton: some View {
        VStack(spacing: theme.spacingSM) {
            // Summary tiles placeholder
            HStack(spacing: theme.spacingSM) {
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .fill(theme.bgSecondary)
                    .frame(height: 80)
                    .shimmer()
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .fill(theme.bgSecondary)
                    .frame(height: 80)
                    .shimmer()
            }

            // Pattern row placeholders
            ForEach(0..<5, id: \.self) { _ in
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .fill(theme.bgSecondary)
                    .frame(height: 96)
                    .shimmer()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading error patterns")
    }

    // MARK: - Empty State

    /// Placeholder view shown when no patterns are detected for the filter.
    private var emptyState: some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 48, design: theme.fontDesign))
                .foregroundStyle(theme.success)

            Text("No Recurring Errors")
                .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Text(
                viewModel.selectedProject != nil
                    ? "No recurring error patterns detected for \(viewModel.selectedProject!)."
                    : "No recurring error patterns detected across your projects."
            )
            .font(.system(size: theme.fontBody, design: theme.fontDesign))
            .foregroundStyle(theme.textSecondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(theme.spacingLG)
        .modifier(GlassCard())
        .accessibilityElement(children: .combine)
    }

    // MARK: - Helpers

    /// Unique project names derived from the currently loaded patterns.
    private var availableProjects: [String] {
        let names = viewModel.patterns.map(\.projectName)
        return Array(Set(names)).sorted()
    }
}

// MARK: - Error Pattern Row

/// Expandable card row for a single ``ErrorPattern``.
///
/// Displays the error type badge, summary, occurrence count, top-fix confidence,
/// and resolution status in collapsed form.  Tapping expands a section listing
/// all ``ErrorFix`` suggestions with their confidence scores.
private struct ErrorPatternRow: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// The error pattern to display.
    let pattern: ErrorPattern
    /// Whether the fix list is currently expanded.
    let isExpanded: Bool
    /// Callback fired when the row header is tapped to expand/collapse.
    let onToggle: () -> Void
    /// Callback fired when the "View Details" button is tapped to open the detail sheet.
    let onViewDetail: () -> Void
    /// Callback fired when the "Mark Resolved" button is tapped.
    let onResolve: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsed header row — always visible
            Button(action: onToggle) {
                HStack(alignment: .top, spacing: theme.spacingSM) {
                    // Error type badge
                    errorTypeBadge

                    // Summary and signature
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pattern.summary)
                            .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text(pattern.errorSignature)
                            .font(.system(size: theme.fontCaption, design: .monospaced))
                            .foregroundStyle(theme.textTertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer()

                    // Right-hand meta column
                    VStack(alignment: .trailing, spacing: 4) {
                        occurrenceBadge
                        if let topFix = pattern.suggestedFixes.first {
                            confidenceBadge(for: topFix.confidence)
                        }
                        resolutionIcon
                    }
                }
                .padding(theme.spacingMD)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(rowAccessibilityLabel)
            .accessibilityHint(isExpanded ? "Tap to collapse" : "Tap to expand and view suggested fixes")

            // Expanded section — suggested fixes and resolve button
            if isExpanded {
                Divider()
                    .background(theme.bgSecondary)
                    .padding(.horizontal, theme.spacingSM)

                expandedContent
            }
        }
        .modifier(GlassCard())
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }

    // MARK: - Header Components

    /// Colour-coded pill showing the error category.
    private var errorTypeBadge: some View {
        Text(pattern.errorType)
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(errorTypeColor.opacity(0.9))
            .padding(.horizontal, theme.spacingXS)
            .padding(.vertical, 3)
            .background(errorTypeColor.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            .frame(minWidth: 60)
            .accessibilityLabel("Error type: \(pattern.errorType)")
    }

    /// Badge showing occurrence count.
    private var occurrenceBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "repeat")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
            Text("\(pattern.occurrenceCount)×")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
        }
        .foregroundStyle(theme.textSecondary)
        .accessibilityLabel("\(pattern.occurrenceCount) occurrences")
    }

    /// Confidence badge derived from the top-ranked suggested fix.
    private func confidenceBadge(for confidence: Double) -> some View {
        let pct = Int(confidence * 100)
        let color = confidenceColor(for: confidence)
        return HStack(spacing: 3) {
            Image(systemName: "sparkles")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
            Text("\(pct)%")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
        }
        .foregroundStyle(color)
        .accessibilityLabel("Fix confidence: \(pct)%")
    }

    /// Checkmark or clock icon indicating resolution status.
    private var resolutionIcon: some View {
        Image(systemName: pattern.isResolved ? "checkmark.circle.fill" : "clock.badge.exclamationmark")
            .font(.system(size: 14, design: theme.fontDesign))
            .foregroundStyle(pattern.isResolved ? theme.success : theme.warning)
            .accessibilityLabel(pattern.isResolved ? "Resolved" : "Unresolved")
    }

    // MARK: - Expanded Content

    /// Expanded section listing suggested fixes and a resolve button.
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            if !pattern.suggestedFixes.isEmpty {
                Text("Suggested Fixes")
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .padding(.top, theme.spacingXS)
                    .padding(.horizontal, theme.spacingMD)

                ForEach(pattern.suggestedFixes) { fix in
                    fixRow(fix: fix)
                }
            }

            // Affected sessions note
            HStack(spacing: theme.spacingXS) {
                Image(systemName: "text.bubble")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                Text("\(pattern.affectedSessionCount) session\(pattern.affectedSessionCount == 1 ? "" : "s") affected")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(.horizontal, theme.spacingMD)

            // View Details button — opens the detail sheet with full
            // occurrence history, copyable fix prompts, and apply-fix action
            Button(action: onViewDetail) {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "arrow.up.right.square")
                    Text("View Details & Apply Fix")
                }
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacingXS)
                .background(theme.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, theme.spacingMD)
            .accessibilityLabel("View full details and apply suggested fix for this error pattern")

            // Resolve button (only for unresolved patterns)
            if !pattern.isResolved {
                Button(action: onResolve) {
                    HStack(spacing: theme.spacingXS) {
                        Image(systemName: "checkmark.circle")
                        Text("Mark as Resolved")
                    }
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.success)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingXS)
                    .background(theme.success.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, theme.spacingMD)
                .padding(.bottom, theme.spacingXS)
                .accessibilityLabel("Mark this error pattern as resolved")
            }
        }
        .padding(.bottom, theme.spacingXS)
    }

    /// A single suggested fix row with confidence bar.
    private func fixRow(fix: ErrorFix) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(fix.description)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(2)

            // Confidence progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.bgSecondary)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(confidenceColor(for: fix.confidence).gradient)
                        .frame(
                            width: geo.size.width * min(max(fix.confidence, 0), 1),
                            height: 4
                        )
                }
            }
            .frame(height: 4)

            Text("\(fix.successCount) successful • \(fix.failureCount) failed")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(.horizontal, theme.spacingMD)
        .padding(.vertical, theme.spacingXS)
    }

    // MARK: - Helpers

    /// Colour for the error type badge based on error category.
    private var errorTypeColor: Color {
        switch pattern.errorType.lowercased() {
        case "compilation", "compile": return theme.error
        case "test_failure", "test":   return theme.warning
        case "lint", "linting":        return theme.entitySystem
        case "runtime":                return Color.purple
        default:                       return theme.accent
        }
    }

    /// Colour for the confidence badge/bar based on threshold levels.
    ///
    /// - Parameter confidence: Value from 0.0 to 1.0.
    /// - Returns: Green for ≥ 0.8, orange for ≥ 0.5, red otherwise.
    private func confidenceColor(for confidence: Double) -> Color {
        if confidence >= 0.8 { return theme.success }
        if confidence >= 0.5 { return theme.warning }
        return theme.error
    }

    /// Combined VoiceOver label for the collapsed row.
    private var rowAccessibilityLabel: String {
        let resolved = pattern.isResolved ? "resolved" : "unresolved"
        let confidence = pattern.suggestedFixes.first.map {
            ", \(Int($0.confidence * 100))% confidence fix available"
        } ?? ""
        return "\(pattern.summary), \(pattern.occurrenceCount) occurrences, \(resolved)\(confidence)"
    }
}

// MARK: - Error Stat Tile

/// Compact metric tile used in the summary header grid.
private struct ErrorStatTile: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: theme.fontBody))
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(.system(size: theme.fontTitle2, weight: .bold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(label)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .padding(theme.spacingMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ErrorPatternsView()
            .environment(AppState())
            .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
    }
}
