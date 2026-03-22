import SwiftUI
import ILSShared

// MARK: - Voice Command Settings

/// Settings view for configuring voice command behaviour.
///
/// Provides controls for:
/// - **Master Enable** — toggle voice commands on/off.
/// - **Recognition** — language hint and continuous listening mode.
/// - **Confidence Thresholds** — sliders for high/medium confidence matching.
/// - **Safety** — require confirmation for all commands; destructive command guard.
/// - **Offline Queue** — enable/disable offline command queueing.
/// - **History** — view recent interpretation history and clear it.
struct VoiceCommandSettingsView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    // MARK: - Persisted Settings

    @AppStorage("voiceCommandsEnabled") private var voiceCommandsEnabled: Bool = true
    @AppStorage("voiceCommandAlwaysConfirm") private var alwaysConfirm: Bool = false
    @AppStorage("voiceCommandHighConfidence") private var highConfidence: Double = 0.8
    @AppStorage("voiceCommandMediumConfidence") private var mediumConfidence: Double = 0.5
    @AppStorage("voiceCommandContinuousListening") private var continuousListening: Bool = false
    @AppStorage("voiceCommandOfflineQueue") private var offlineQueueEnabled: Bool = true
    @AppStorage("voiceCommandHapticFeedback") private var hapticFeedback: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Voice Commands")

            enableSection

            recognitionSection

            confidenceSection

            safetySection

            offlineQueueSection

            commandCatalogSection

            Text("Voice commands let you control the app hands-free using speech recognition. Adjust confidence thresholds to fine-tune matching accuracy.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
    }

    // MARK: - Enable Section

    private var enableSection: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $voiceCommandsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Voice Commands")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Text("Use speech to control sessions and approve permissions")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .tint(theme.accent)
            .padding(theme.spacingMD)
            .accessibilityLabel("Enable voice commands")
            .onChange(of: voiceCommandsEnabled) {
                #if os(iOS)
                HapticManager.selection()
                #endif
            }
        }
        .modifier(GlassCard())
    }

    // MARK: - Recognition Section

    private var recognitionSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Recognition")

            VStack(spacing: 0) {
                Toggle(isOn: $continuousListening) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Continuous Listening")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                        Text("Keep microphone active between commands")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                .tint(theme.accent)
                .padding(theme.spacingMD)
                .accessibilityLabel("Continuous listening mode")

                Divider().background(theme.bgTertiary)

                Toggle(isOn: $hapticFeedback) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Haptic Feedback")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                        Text("Vibrate on command recognition and execution")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                .tint(theme.accent)
                .padding(theme.spacingMD)
                .accessibilityLabel("Haptic feedback for voice commands")
            }
            .modifier(GlassCard())
        }
        .disabled(!voiceCommandsEnabled)
        .opacity(voiceCommandsEnabled ? 1 : 0.5)
    }

    // MARK: - Confidence Thresholds

    private var confidenceSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Confidence Thresholds")

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    HStack {
                        Text("High Confidence")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Text("\(Int(highConfidence * 100))%")
                            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                            .foregroundStyle(theme.accent)
                    }
                    Slider(value: $highConfidence, in: 0.6...1.0, step: 0.05)
                        .tint(theme.accent)
                        .accessibilityLabel("High confidence threshold: \(Int(highConfidence * 100)) percent")
                    Text("Commands matching above this threshold execute immediately.")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
                .padding(theme.spacingMD)

                Divider().background(theme.bgTertiary)

                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    HStack {
                        Text("Medium Confidence")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Text("\(Int(mediumConfidence * 100))%")
                            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                            .foregroundStyle(theme.accent)
                    }
                    Slider(value: $mediumConfidence, in: 0.3...0.8, step: 0.05)
                        .tint(theme.accent)
                        .accessibilityLabel("Medium confidence threshold: \(Int(mediumConfidence * 100)) percent")
                    Text("Commands between medium and high confidence require confirmation.")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
                .padding(theme.spacingMD)
            }
            .modifier(GlassCard())
        }
        .disabled(!voiceCommandsEnabled)
        .opacity(voiceCommandsEnabled ? 1 : 0.5)
    }

    // MARK: - Safety Section

    private var safetySection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Safety")

            VStack(spacing: 0) {
                Toggle(isOn: $alwaysConfirm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Always Require Confirmation")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                        Text("Ask for confirmation before executing any voice command")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                .tint(theme.accent)
                .padding(theme.spacingMD)
                .accessibilityLabel("Always require confirmation for voice commands")
            }
            .modifier(GlassCard())
        }
        .disabled(!voiceCommandsEnabled)
        .opacity(voiceCommandsEnabled ? 1 : 0.5)
    }

    // MARK: - Offline Queue Section

    private var offlineQueueSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Offline Queue")

            VStack(spacing: 0) {
                Toggle(isOn: $offlineQueueEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Queue Commands Offline")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                        Text("Save commands when offline and execute when reconnected")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                .tint(theme.accent)
                .padding(theme.spacingMD)
                .accessibilityLabel("Enable offline voice command queue")
            }
            .modifier(GlassCard())
        }
        .disabled(!voiceCommandsEnabled)
        .opacity(voiceCommandsEnabled ? 1 : 0.5)
    }

    // MARK: - Command Catalog Section

    /// Groups commands by category for the catalog display.
    private var commandsByCategory: [(VoiceCommandCategory, [VoiceCommand])] {
        VoiceCommandCategory.allCases.compactMap { category in
            let commands = VoiceCommandCatalog.commands(for: category)
            return commands.isEmpty ? nil : (category, commands)
        }
    }

    private var commandCatalogSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Available Commands")

            VStack(spacing: 0) {
                ForEach(Array(commandsByCategory.enumerated()), id: \.offset) { index, group in
                    let (category, commands) = group

                    if index > 0 {
                        Divider().background(theme.bgTertiary)
                    }

                    VStack(alignment: .leading, spacing: theme.spacingXS) {
                        // Category header
                        HStack(spacing: theme.spacingXS) {
                            Image(systemName: category.icon)
                                .font(.system(size: 12, design: theme.fontDesign))
                                .foregroundStyle(theme.accent)
                            Text(category.displayName)
                                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)
                        }

                        // Command list
                        ForEach(commands, id: \.id) { command in
                            HStack(spacing: theme.spacingSM) {
                                Image(systemName: command.icon)
                                    .font(.system(size: 14, design: theme.fontDesign))
                                    .foregroundStyle(theme.accent)
                                    .frame(width: 20, height: 20)

                                VStack(alignment: .leading, spacing: 1) {
                                    HStack(spacing: theme.spacingXS) {
                                        Text(command.displayName)
                                            .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                                            .foregroundStyle(theme.textPrimary)

                                        if command.isDestructive {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                                .foregroundStyle(theme.error)
                                        }
                                    }

                                    Text("Say: \"\(command.phrases.first ?? command.displayName)\"")
                                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                        .foregroundStyle(theme.textTertiary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                if command.offlineCapable {
                                    Image(systemName: "wifi.slash")
                                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                        .foregroundStyle(theme.textTertiary)
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(command.displayName): say \(command.phrases.first ?? command.displayName)")
                        }
                    }
                    .padding(theme.spacingMD)
                }
            }
            .modifier(GlassCard())
        }
        .disabled(!voiceCommandsEnabled)
        .opacity(voiceCommandsEnabled ? 1 : 0.5)
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
}

#Preview {
    ScrollView {
        VoiceCommandSettingsView()
            .padding()
    }
}
