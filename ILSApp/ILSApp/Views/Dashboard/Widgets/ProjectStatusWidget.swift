import SwiftUI
import ILSShared
import Observation

// MARK: - ProjectStatusWidgetViewModel

/// View model for the Project Status dashboard widget.
///
/// Loads projects from the `/projects` API endpoint and surfaces the five most
/// recently-accessed projects sorted by `lastAccessedAt` descending.
///
/// ## Topics
/// ### Configuration
/// - ``configure(client:)`` - Bind to a direct API client for data loading
///
/// ### Data
/// - ``projects`` - Up to five most-recently-accessed projects
/// - ``totalCount`` - Total number of projects (may exceed five)
@Observable
@MainActor
final class ProjectStatusWidgetViewModel: DashboardWidgetViewModel {

    // MARK: DashboardWidgetViewModel

    /// True while the widget is fetching its initial or refreshed data.
    private(set) var isLoading = true
    /// True when the backend is unreachable.
    private(set) var isOffline = false

    // MARK: Data

    /// Up to five projects sorted by most-recently-accessed first.
    private(set) var projects: [Project] = []
    /// Total number of available projects; may exceed `projects.count`.
    private(set) var totalCount: Int = 0

    // MARK: Private

    /// Direct API client for fetching project data.
    private var client: APIClient?

    // MARK: Init

    init() {}

    // MARK: Configuration

    /// Bind this view model to a direct API client.
    /// - Parameter client: The ``APIClient`` for fetching projects.
    func configure(client: APIClient) {
        self.client = client
    }

    // MARK: DashboardWidgetViewModel

    /// Fetches project data from the API.
    func loadContent() async {
        isLoading = true
        isOffline = false

        guard let client else {
            isLoading = false
            return
        }
        await fetchFromAPI(client: client)
    }

    // MARK: Private Helpers

    /// Fetch projects from the API and surface the five most recently accessed.
    private func fetchFromAPI(client: APIClient) async {
        do {
            let response: APIResponse<ListResponse<Project>> =
                try await client.get("/projects?limit=20&offset=0")
            let all = response.data?.items ?? []
            totalCount = response.data?.total ?? all.count
            projects = Array(
                all.sorted { $0.lastAccessedAt > $1.lastAccessedAt }.prefix(5)
            )
            isOffline = false
        } catch {
            isOffline = true
            AppLogger.shared.error(
                "ProjectStatusWidget fetch failed: \(error.localizedDescription)",
                category: "widget"
            )
        }
        isLoading = false
    }
}

// MARK: - ProjectStatusWidget

/// Dashboard widget that shows the most recently accessed projects with status indicators.
///
/// Displays up to five projects sorted newest-first, each with a session count badge
/// and a relative last-accessed timestamp.  While data loads, skeleton rows shimmer
/// as placeholders.  If no projects exist, an empty-state prompt guides the user to
/// create their first project.
///
/// ## Usage
/// ```swift
/// ProjectStatusWidget(viewModel: vm) { project in
///     navigateTo(project)
/// }
/// ```
struct ProjectStatusWidget: View {
    /// View model supplying project data and loading state.
    let viewModel: ProjectStatusWidgetViewModel
    /// Called when the user taps a project row.
    var onProjectSelected: ((Project) -> Void)?

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()
                .background(theme.bgTertiary)

            if viewModel.isLoading {
                skeletonContent
            } else if viewModel.isOffline {
                offlineState
            } else if viewModel.projects.isEmpty {
                emptyState
            } else {
                projectList
            }

            Spacer(minLength: 0)
        }
        .padding(theme.spacingMD)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: DashboardWidgetType.projectStatus.icon)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.entityProject)
                .accessibilityHidden(true)

            Text("Project Status")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Spacer()

            if !viewModel.isLoading && viewModel.totalCount > 0 {
                countBadge
            }
        }
        .padding(.bottom, theme.spacingSM)
    }

    private var countBadge: some View {
        Text("\(viewModel.totalCount)")
            .font(.system(size: theme.fontCaption, weight: .bold, design: theme.fontDesign))
            .foregroundStyle(theme.textOnAccent)
            .padding(.horizontal, theme.spacingXS + 2)
            .padding(.vertical, 2)
            .background(theme.entityProject)
            .clipShape(Capsule())
            .accessibilityLabel("\(viewModel.totalCount) \(viewModel.totalCount == 1 ? "project" : "projects")")
    }

    // MARK: - Project List

    private var projectList: some View {
        VStack(spacing: theme.spacingXS) {
            ForEach(viewModel.projects) { project in
                projectRow(project)
            }

            if viewModel.totalCount > 5 {
                Text("+\(viewModel.totalCount - 5) more")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, theme.spacingXS)
            }
        }
        .padding(.top, theme.spacingSM)
    }

    @ViewBuilder
    private func projectRow(_ project: Project) -> some View {
        Button {
            onProjectSelected?(project)
        } label: {
            HStack(spacing: theme.spacingSM) {
                // Project color indicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.entityProject)
                    .frame(width: 3, height: 32)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: theme.spacingXS) {
                        if let sessions = project.sessionCount, sessions > 0 {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: theme.fontCaption - 1, design: theme.fontDesign))
                                .foregroundStyle(theme.entitySession)
                                .accessibilityHidden(true)
                            Text("\(sessions)")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.entitySession)

                            Text("·")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textTertiary)
                        }

                        Text(project.lastAccessedAt.relativeDisplayString)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: theme.fontCaption - 1, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, theme.spacingXS)
            .background(theme.bgTertiary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            .contentShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(projectAccessibilityLabel(project))
        .accessibilityHint("Opens this project")
        .accessibilityAddTraits(.isButton)
    }

    /// Accessibility label for a project row.
    private func projectAccessibilityLabel(_ project: Project) -> String {
        var parts = [project.name]
        if let sessions = project.sessionCount, sessions > 0 {
            parts.append("\(sessions) \(sessions == 1 ? "session" : "sessions")")
        }
        parts.append("last accessed \(project.lastAccessedAt.relativeDisplayString)")
        return parts.joined(separator: ", ")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: theme.spacingSM) {
            Image(systemName: "folder")
                .font(.system(size: theme.fontTitle2, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            Text("No Projects")
                .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, theme.spacingMD)
        .accessibilityLabel("No projects")
    }

    // MARK: - Offline State

    private var offlineState: some View {
        VStack(spacing: theme.spacingSM) {
            Image(systemName: "wifi.slash")
                .font(.system(size: theme.fontTitle2, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            Text("Offline")
                .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, theme.spacingMD)
        .accessibilityLabel("Project status unavailable — offline")
    }

    // MARK: - Skeleton

    private var skeletonContent: some View {
        VStack(spacing: theme.spacingXS) {
            ForEach(0..<4, id: \.self) { _ in
                skeletonRow
            }
        }
        .padding(.top, theme.spacingSM)
    }

    private var skeletonRow: some View {
        HStack(spacing: theme.spacingSM) {
            RoundedRectangle(cornerRadius: 2)
                .fill(theme.bgTertiary)
                .frame(width: 3, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(theme.bgTertiary)
                    .frame(width: 120, height: 13)

                HStack(spacing: theme.spacingXS) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.bgTertiary)
                        .frame(width: 40, height: 10)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.bgTertiary)
                        .frame(width: 55, height: 10)
                }
            }

            Spacer()
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, theme.spacingXS)
        .background(theme.bgTertiary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .shimmer()
        .accessibilityHidden(true)
    }
}

// MARK: - Date + Relative Display

private extension Date {
    /// Short relative string (e.g. "just now", "2m ago", "3d ago").
    var relativeDisplayString: String {
        let interval = Date().timeIntervalSince(self)
        switch interval {
        case ..<60:
            return "just now"
        case 60..<3600:
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        case 3600..<86400:
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        case 86400..<604800:
            let days = Int(interval / 86400)
            return "\(days)d ago"
        default:
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: self)
        }
    }
}

// MARK: - Preview

#Preview {
    ProjectStatusWidget(viewModel: ProjectStatusWidgetViewModel())
        .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
        .frame(width: 320, height: 240)
        .glassCard()
        .padding()
}
