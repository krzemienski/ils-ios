import Foundation
import Observation
import SwiftUI
import ILSShared

// MARK: - Analytics Period

/// Time period for analytics queries.
enum AnalyticsPeriod: String, CaseIterable {
    case week = "week"
    case month = "month"

    /// Human-readable label for the period.
    var label: String {
        switch self {
        case .week: return "Last 7 Days"
        case .month: return "Last 30 Days"
        }
    }
}

// MARK: - AnalyticsViewModel

@MainActor
@Observable
class AnalyticsViewModel {
    var activityTimeline: ActivityTimelineResponse?
    var sessionMetrics: SessionMetricsResponse?
    var skillAnalytics: SkillAnalyticsResponse?
    var summary: AnalyticsSummary?
    var isLoading = false
    var error: Error?
    var selectedPeriod: AnalyticsPeriod = .week

    @AppStorage("analyticsEnabled") private var analyticsEnabled = true

    private var client: APIClient?

    init() {}

    func configure(client: APIClient) {
        self.client = client
    }

    /// Empty state text for UI display.
    var emptyStateText: String {
        if isLoading {
            return "Loading analytics..."
        }
        return summary == nil ? "No analytics data available" : ""
    }

    // MARK: - Load Methods

    /// Load all analytics data in parallel.
    func loadAll() async {
        guard analyticsEnabled else {
            AppLogger.shared.info("Analytics disabled by user preference", category: "analytics")
            return
        }
        guard client != nil else { return }

        isLoading = true
        error = nil

        async let activityResult: Void = loadActivity()
        async let sessionResult: Void = loadSessionMetrics()
        async let skillResult: Void = loadSkillAnalytics()
        async let summaryResult: Void = loadSummary()
        _ = await (activityResult, sessionResult, skillResult, summaryResult)

        isLoading = false
    }

    /// Load the activity timeline for the selected period.
    func loadActivity() async {
        guard let client else { return }
        do {
            let response: APIResponse<ActivityTimelineResponse> = try await client.get(
                "/analytics/activity?period=\(selectedPeriod.rawValue)"
            )
            if let data = response.data {
                activityTimeline = data
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to load activity timeline: \(error.localizedDescription)", category: "analytics")
        }
    }

    /// Load session effectiveness metrics.
    func loadSessionMetrics() async {
        guard let client else { return }
        do {
            let response: APIResponse<SessionMetricsResponse> = try await client.get("/analytics/sessions")
            if let data = response.data {
                sessionMetrics = data
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to load session metrics: \(error.localizedDescription)", category: "analytics")
        }
    }

    /// Load skill usage analytics.
    func loadSkillAnalytics() async {
        guard let client else { return }
        do {
            let response: APIResponse<SkillAnalyticsResponse> = try await client.get("/analytics/skills")
            if let data = response.data {
                skillAnalytics = data
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to load skill analytics: \(error.localizedDescription)", category: "analytics")
        }
    }

    /// Load the high-level analytics summary for the selected period.
    func loadSummary() async {
        guard let client else { return }
        do {
            let response: APIResponse<AnalyticsSummary> = try await client.get(
                "/analytics/summary?period=\(selectedPeriod.rawValue)"
            )
            if let data = response.data {
                summary = data
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to load analytics summary: \(error.localizedDescription)", category: "analytics")
        }
    }

    /// Export all analytics data as a single payload.
    func exportData() async -> AnalyticsExportData? {
        guard analyticsEnabled else { return nil }
        guard let client else { return nil }
        do {
            let response: APIResponse<AnalyticsExportData> = try await client.get("/analytics/export")
            return response.data
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to export analytics data: \(error.localizedDescription)", category: "analytics")
            return nil
        }
    }

    /// Reload all analytics data (used for retry and period changes).
    func retryLoad() async {
        await loadAll()
    }
}
