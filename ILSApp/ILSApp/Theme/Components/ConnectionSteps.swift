import SwiftUI

// MARK: - Connection Step Model

enum StepStatus: Equatable {
    case pending
    case inProgress
    case success
    case failure(String)
}

struct ConnectionStep: Identifiable {
    let id: Int
    let name: String
    let icon: String
    var status: StepStatus
}

// MARK: - ConnectionStepsView

/// Multi-step connection progress indicator showing DNS Resolve, TCP Connect, Health Check.
/// Each step shows a checkmark (success), spinner (in-progress), X (failure), or circle (pending).
struct ConnectionStepsView: View {
    let steps: [ConnectionStep]
    @Environment(\.theme) private var theme: any AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(steps) { step in
                HStack(spacing: 12) {
                    stepIndicator(for: step.status)
                        .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.name)
                            .font(.system(size: theme.fontBody))
                            .foregroundColor(textColor(for: step.status))

                        if case .failure(let msg) = step.status {
                            Text(msg)
                                .font(.system(size: theme.fontCaption))
                                .foregroundColor(theme.error)
                        }
                    }

                    Spacer()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(stepAccessibilityLabel(for: step))
            }
        }
    }

    @ViewBuilder
    private func stepIndicator(for status: StepStatus) -> some View {
        switch status {
        case .pending:
            Circle()
                .stroke(theme.textTertiary, lineWidth: 2)
                .frame(width: 20, height: 20)
        case .inProgress:
            ProgressView()
                .controlSize(.small)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(theme.success)
                .font(.title3)
        case .failure:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(theme.error)
                .font(.title3)
        }
    }

    private func stepAccessibilityLabel(for step: ConnectionStep) -> String {
        let statusText: String
        switch step.status {
        case .pending:
            statusText = "pending"
        case .inProgress:
            statusText = "in progress"
        case .success:
            statusText = "completed"
        case .failure(let msg):
            statusText = "failed, \(msg)"
        }
        return "Step \(step.id): \(step.name), \(statusText)"
    }

    private func textColor(for status: StepStatus) -> Color {
        switch status {
        case .pending: return theme.textTertiary
        case .inProgress: return theme.textPrimary
        case .success: return theme.success
        case .failure: return theme.error
        }
    }
}
