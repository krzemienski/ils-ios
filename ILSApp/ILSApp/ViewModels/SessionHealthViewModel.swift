import Foundation
import Observation
import SwiftUI
import ILSShared

/// View model for session health score data.
///
/// Fetches per-session health scores and aggregate project health
/// summaries from the backend, and exposes display helpers for views.
@Observable
@MainActor
class SessionHealthViewModel: BaseViewModel {
    var healthScore: SessionHealthScore?
    var projectSummaries: [ProjectHealthSummary] = []
    var isLoadingHealth = false
    var healthError: String?

    // MARK: - Data Fetching

    func loadHealth(sessionId: UUID) async {
        guard let client else { return }
        isLoadingHealth = true
        healthError = nil

        do {
            let response: APIResponse<SessionHealthScore> = try await client.get(
                "/sessions/\(sessionId.uuidString.lowercased())/health"
            )
            if let data = response.data {
                healthScore = data
            } else {
                healthError = "No health data returned"
            }
        } catch {
            healthError = error.localizedDescription
        }

        isLoadingHealth = false
    }

    func loadProjectHealth() async {
        guard let client else { return }
        isLoadingHealth = true
        healthError = nil

        do {
            let response: APIResponse<[ProjectHealthSummary]> = try await client.get(
                "/projects/health"
            )
            if let data = response.data {
                projectSummaries = data
            } else {
                healthError = "No project health data returned"
            }
        } catch {
            healthError = error.localizedDescription
        }

        isLoadingHealth = false
    }

    // MARK: - Display Computed Properties

    /// Color representing the current health level.
    var scoreColor: Color {
        switch healthScore?.level {
        case .healthy:    return .green
        case .degrading:  return .orange
        case .problematic: return .red
        case nil:         return .gray
        }
    }

    /// SF Symbol name representing the current health level.
    var scoreIcon: String {
        switch healthScore?.level {
        case .healthy:    return "checkmark.circle.fill"
        case .degrading:  return "exclamationmark.triangle.fill"
        case .problematic: return "xmark.circle.fill"
        case nil:         return "questionmark.circle"
        }
    }

    /// Human-readable integer score, or "--" when unavailable.
    var formattedScore: String {
        guard let s = healthScore else { return "--" }
        return String(Int(s.score))
    }
}
