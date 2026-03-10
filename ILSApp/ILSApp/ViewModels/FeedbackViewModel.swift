import Foundation
import Observation
import SwiftUI
import ILSShared

// MARK: - FeedbackPeriod

/// Time period for quality trend queries.
enum FeedbackPeriod: String, CaseIterable {
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

// MARK: - FeedbackViewModel

@MainActor
@Observable
class FeedbackViewModel {
    var qualityTrend: QualityTrendResponse?
    var bestOfItems: [BestOfItem] = []
    var isSubmitting = false
    /// Maps messageId → rating string ("thumbsUp" or "thumbsDown") for submitted ratings.
    var submittedRatings: [String: String] = [:]
    var error: Error?

    private var client: APIClient?

    init() {}

    func configure(client: APIClient) {
        self.client = client
    }

    // MARK: - Submit Feedback

    /// Submit feedback for an AI response.
    func submitFeedback(
        rating: FeedbackRating,
        comment: String?,
        message: ChatMessage,
        session: ChatSession,
        project: Project?,
        model: String
    ) async {
        guard let client else { return }

        isSubmitting = true
        error = nil

        let ratingValue = rating == .thumbsUp ? 1 : -1
        let request = SubmitFeedbackRequest(
            rating: ratingValue,
            comment: comment,
            messageId: message.id.uuidString,
            sessionId: session.id.uuidString,
            projectId: project?.id.uuidString ?? "",
            model: model
        )

        do {
            let response: APIResponse<FeedbackResponse> = try await client.post(
                "/feedback",
                body: request
            )
            if response.data != nil {
                submittedRatings[message.id.uuidString] = rating.rawValue
            }
        } catch {
            self.error = error
            AppLogger.shared.error(
                "Failed to submit feedback: \(error.localizedDescription)",
                category: "feedback"
            )
        }

        isSubmitting = false
    }

    // MARK: - Load Quality Trend

    /// Load the quality trend for the given period.
    func loadQualityTrend(period: FeedbackPeriod = .week) async {
        guard let client else { return }
        do {
            let response: APIResponse<QualityTrendResponse> = try await client.get(
                "/feedback/trend?period=\(period.rawValue)"
            )
            if let data = response.data {
                qualityTrend = data
            }
        } catch {
            self.error = error
            AppLogger.shared.error(
                "Failed to load quality trend: \(error.localizedDescription)",
                category: "feedback"
            )
        }
    }

    // MARK: - Load Best Of

    /// Load the highest-rated responses.
    func loadBestOf(limit: Int = 20) async {
        guard let client else { return }
        do {
            let response: APIResponse<[BestOfItem]> = try await client.get(
                "/feedback/best-of?limit=\(limit)"
            )
            if let data = response.data {
                bestOfItems = data
            }
        } catch {
            self.error = error
            AppLogger.shared.error(
                "Failed to load best-of items: \(error.localizedDescription)",
                category: "feedback"
            )
        }
    }

    // MARK: - Helpers

    /// Returns the submitted rating for a given message ID, if any.
    func submittedRating(for messageId: String) -> FeedbackRating? {
        guard let raw = submittedRatings[messageId] else { return nil }
        return FeedbackRating(rawValue: raw)
    }

    /// Whether the user has already rated a given message.
    func hasRated(messageId: String) -> Bool {
        submittedRatings[messageId] != nil
    }
}
