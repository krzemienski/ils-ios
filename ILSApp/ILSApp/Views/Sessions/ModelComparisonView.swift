import SwiftUI
import ILSShared

/// A sheet that compares all known Claude models side-by-side.
///
/// Displays a card per model showing display name, description, speed rating,
/// capability rating, pricing, and recommended use cases. Presented from
/// `NewSessionView` when the user taps the ⓘ button in the Model section.
struct ModelComparisonView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: theme.spacingMD) {
                    ForEach(ClaudeModel.allKnown, id: \.rawValue) { model in
                        modelCard(model)
                    }
                }
                .padding(theme.spacingMD)
            }
            .background(theme.bgPrimary)
            .navigationTitle("Compare Models")
            #if os(iOS)
            .inlineNavigationBarTitle()
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(theme.accent)
                }
            }
        }
    }

    // MARK: - Model Card

    @ViewBuilder
    private func modelCard(_ model: ClaudeModel) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {

            // Header: name + badge
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.displayName)
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Text(model.modelDescription)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                modelBadge(model)
            }

            Divider().overlay(theme.divider)

            // Ratings
            ratingRow(label: "Speed", rating: model.speedRating, maxRating: 3, color: theme.success)
            ratingRow(label: "Capability", rating: model.capabilityRating, maxRating: 3, color: theme.accent)

            Divider().overlay(theme.divider)

            // Pricing
            HStack(spacing: theme.spacingMD) {
                costPill(
                    label: "Input",
                    value: "$\(String(format: "%.2f", model.costPerMInputTokens))/1M"
                )
                costPill(
                    label: "Output",
                    value: "$\(String(format: "%.2f", model.costPerMOutputTokens))/1M"
                )
                Spacer()
            }

            Divider().overlay(theme.divider)

            // Best for
            VStack(alignment: .leading, spacing: 4) {
                Text("Best for:")
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .textCase(.uppercase)
                    .kerning(0.8)
                Text(bestFor(model))
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(theme.spacingMD)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func modelBadge(_ model: ClaudeModel) -> some View {
        let (label, color) = badgeInfo(model)
        Text(label)
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(color)
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func ratingRow(label: String, rating: Int, maxRating: Int, color: Color) -> some View {
        HStack(spacing: theme.spacingSM) {
            Text(label)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 72, alignment: .leading)

            HStack(spacing: 4) {
                ForEach(1...maxRating, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(index <= rating ? color : theme.bgTertiary)
                        .frame(height: 8)
                }
            }

            Text("\(rating)/\(maxRating)")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 28, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func costPill(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .textCase(.uppercase)
                .kerning(0.6)
            Text(value)
                .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
        }
    }

    // MARK: - Helpers

    private func badgeInfo(_ model: ClaudeModel) -> (String, Color) {
        switch model {
        case .haiku:   return ("Fastest", theme.success)
        case .sonnet:  return ("Balanced", theme.accent)
        case .opus:    return ("Most Capable", theme.warning)
        case .unknown: return ("Custom", theme.textTertiary)
        }
    }

    private func bestFor(_ model: ClaudeModel) -> String {
        switch model {
        case .haiku:
            return "Quick lookups, code completions, summarisation, high-volume automation, and any task where response speed matters most."
        case .sonnet:
            return "Everyday coding, pull request reviews, documentation, debugging, and general-purpose assistant work."
        case .opus:
            return "Complex architecture decisions, multi-step reasoning, in-depth analysis, nuanced writing, and tasks requiring deep contextual understanding."
        case .unknown:
            return "Custom or experimental model."
        }
    }
}

#Preview {
    ModelComparisonView()
        .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
