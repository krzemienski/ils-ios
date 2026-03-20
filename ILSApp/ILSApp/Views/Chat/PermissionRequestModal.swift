import SwiftUI
import ILSShared

/// Common deny reason labels presented to the user when denying a permission request.
///
/// Each case maps to a `DenialReasonCode` for structured reporting. The `.custom` case
/// lets the user type a free-form reason.
enum DenyReasonOption: String, CaseIterable, Identifiable {
    case tooRisky = "Too risky"
    case wrongFile = "Wrong file"
    case notNeeded = "Not needed"
    case custom = "Custom…"

    var id: String { rawValue }

    /// Maps the user-facing option to a ``DenialReasonCode`` for backend reporting.
    var reasonCode: DenialReasonCode {
        switch self {
        case .tooRisky: return .highRiskBlocked
        case .wrongFile: return .pathNotAllowed
        case .notNeeded: return .outOfScope
        case .custom: return .userDenied
        }
    }
}

/// Sheet that interrupts the chat flow to let the user approve, deny, or request
/// modification of a Claude tool-use request.
///
/// Structured as a fixed three-zone layout: a header with a shield icon and "Permission Required"
/// title, a scrollable body embedding ``StepPreviewSection`` for rich action preview with risk
/// and policy context, and a pinned footer with Deny, Request Modification, and Allow buttons.
///
/// When the user taps Deny, an optional reason code picker slides in so they can classify why
/// they denied the action. The deny reason code is appended to the decision string
/// (e.g. `"deny:high_risk_blocked"`).
///
/// The "Request Modification" button sends `"deny:modification_requested"` to signal that the
/// user wants Claude to adjust its approach rather than fully denying the action.
///
/// ## Topics
/// ### Input Properties
/// - ``request`` - The `PermissionRequest` model describing the tool name and encoded input
/// - ``riskLevel`` - Assessed risk level for the request (defaults to `.medium`)
/// - ``policyEvaluation`` - Optional policy evaluation result showing which policy matched
///
/// ### Callbacks
/// - ``onDecision`` - Called with a decision string before the sheet is dismissed
// TODO: SUIA-001 — Move API calls to a PermissionRequestViewModel for testability
struct PermissionRequestModal: View {
    /// The permission request describing which tool Claude wants to invoke and its input payload.
    let request: PermissionRequest
    /// Assessed risk level for color-coded badge display. Defaults to `.medium`.
    var riskLevel: PermissionRiskLevel = .medium
    /// Optional policy evaluation result explaining which policy matched and why.
    var policyEvaluation: PolicyEvaluationResult?
    /// Called with a decision string when the user taps an action button.
    /// Possible values: `"allow"`, `"deny"`, `"deny:<reason_code>"`,
    /// `"deny:modification_requested"`.
    /// The sheet is dismissed immediately after this closure returns.
    let onDecision: (String) -> Void

    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.dismiss) private var dismiss

    /// Whether the deny reason picker is visible.
    @State private var showDenyReasons = false
    /// The selected deny reason option.
    @State private var selectedDenyReason: DenyReasonOption?
    /// Custom reason text when `.custom` is selected.
    @State private var customDenyReason: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider().overlay(theme.divider)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacingMD) {
                    StepPreviewSection(
                        request: request,
                        riskLevel: riskLevel,
                        policyEvaluation: policyEvaluation
                    )

                    if showDenyReasons {
                        denyReasonPicker
                    }
                }
                .padding(theme.spacingMD)
            }

            Divider().overlay(theme.divider)

            // Action buttons
            actionButtons
        }
        .background(theme.bgPrimary)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 20, design: theme.fontDesign))
                .foregroundStyle(theme.warning)

            VStack(alignment: .leading, spacing: 2) {
                Text("Permission Required")
                    .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Text("Claude wants to use a tool")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer()

            // Risk level badge in header
            Text(riskLevel.rawValue.uppercased())
                .font(.system(size: theme.fontCaption, weight: .bold, design: theme.fontDesign))
                .foregroundStyle(riskBadgeColor)
                .padding(.horizontal, theme.spacingSM)
                .padding(.vertical, theme.spacingXS)
                .background(riskBadgeColor.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(theme.spacingMD)
    }

    // MARK: - Deny Reason Picker

    private var denyReasonPicker: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("DENY REASON")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .textCase(.uppercase)
                .kerning(1)

            VStack(spacing: theme.spacingXS) {
                ForEach(DenyReasonOption.allCases) { reason in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedDenyReason = reason
                        }
                    } label: {
                        HStack(spacing: theme.spacingSM) {
                            Image(systemName: selectedDenyReason == reason ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                .foregroundStyle(selectedDenyReason == reason ? theme.accent : theme.textTertiary)

                            Text(reason.rawValue)
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)

                            Spacer()
                        }
                        .padding(.vertical, theme.spacingXS)
                        .padding(.horizontal, theme.spacingSM)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                if selectedDenyReason == .custom {
                    TextField("Reason…", text: $customDenyReason)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .padding(theme.spacingSM)
                        .background(theme.bgPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(theme.spacingSM)
            .modifier(GlassCard())
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: theme.spacingSM) {
            // Primary row: Deny, Request Modification, Allow
            HStack(spacing: theme.spacingSM) {
                // Deny button
                Button {
                    if showDenyReasons {
                        // Submit the deny with selected reason
                        let decision = buildDenyDecision()
                        onDecision(decision)
                        dismiss()
                    } else {
                        // Show reason picker
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showDenyReasons = true
                        }
                    }
                } label: {
                    HStack(spacing: theme.spacingXS) {
                        Image(systemName: "xmark.circle.fill")
                        Text(showDenyReasons ? "Confirm Deny" : "Deny")
                            .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    }
                    .foregroundStyle(theme.error)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingSM + 2)
                    .background(theme.error.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }
                .accessibilityLabel(showDenyReasons ? "Confirm deny permission" : "Deny permission")

                // Allow button
                Button {
                    onDecision("allow")
                    dismiss()
                } label: {
                    HStack(spacing: theme.spacingXS) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Allow")
                            .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    }
                    .foregroundStyle(theme.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingSM + 2)
                    .background(theme.success)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }
                .accessibilityLabel("Allow permission")
            }

            // Request Modification button (secondary)
            Button {
                onDecision("deny:modification_requested")
                dismiss()
            } label: {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Request Modification")
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                }
                .foregroundStyle(theme.warning)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacingSM)
                .background(theme.warning.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            }
            .accessibilityLabel("Request modification")
        }
        .padding(theme.spacingMD)
    }

    // MARK: - Helpers

    /// Builds the deny decision string including the selected reason code.
    private func buildDenyDecision() -> String {
        guard let reason = selectedDenyReason else {
            return "deny"
        }
        return "deny:\(reason.reasonCode.rawValue)"
    }

    private var riskBadgeColor: Color {
        switch riskLevel {
        case .low:
            return theme.success
        case .medium:
            return theme.warning
        case .high, .critical:
            return theme.error
        }
    }
}
