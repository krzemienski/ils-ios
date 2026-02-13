import SwiftUI

// MARK: - Theme Metadata

/// Metadata for themes that aren't yet fully implemented as AppTheme conformers.
/// Used to display preview cards in the theme picker grid.
private struct ThemePreview: Identifiable {
    let id: String
    let name: String
    let accent: Color
    let bgPrimary: Color
    let textPrimary: Color
    let bgSecondary: Color
    let isLight: Bool

    static let all: [ThemePreview] = [
        ThemePreview(id: "obsidian", name: "Obsidian", accent: Color(hex: "FF6933"), bgPrimary: Color(hex: "0A0A0F"), textPrimary: Color(hex: "E8E8ED"), bgSecondary: Color(hex: "141419"), isLight: false),
        ThemePreview(id: "slate", name: "Slate", accent: Color(hex: "3B82F6"), bgPrimary: Color(hex: "0F1117"), textPrimary: Color(hex: "E0E4EB"), bgSecondary: Color(hex: "181B24"), isLight: false),
        ThemePreview(id: "midnight", name: "Midnight", accent: Color(hex: "10B981"), bgPrimary: Color(hex: "0A0F0D"), textPrimary: Color(hex: "D8E8E0"), bgSecondary: Color(hex: "131A16"), isLight: false),
        ThemePreview(id: "ghost-protocol", name: "Ghost Protocol", accent: Color(hex: "7DF9FF"), bgPrimary: Color(hex: "08080C"), textPrimary: Color(hex: "E4E4EC"), bgSecondary: Color(hex: "111117"), isLight: false),
        ThemePreview(id: "neon-noir", name: "Neon Noir", accent: Color(hex: "00D4FF"), bgPrimary: Color(hex: "0A0A0F"), textPrimary: Color(hex: "E0E8F0"), bgSecondary: Color(hex: "12121A"), isLight: false),
        ThemePreview(id: "electric-grid", name: "Electric Grid", accent: Color(hex: "00FF88"), bgPrimary: Color(hex: "050510"), textPrimary: Color(hex: "D8E8D8"), bgSecondary: Color(hex: "0E0E1A"), isLight: false),
        ThemePreview(id: "ember", name: "Ember", accent: Color(hex: "F59E0B"), bgPrimary: Color(hex: "0F0D0A"), textPrimary: Color(hex: "E8E4D8"), bgSecondary: Color(hex: "1A1714"), isLight: false),
        ThemePreview(id: "crimson", name: "Crimson", accent: Color(hex: "EF4444"), bgPrimary: Color(hex: "0F0A0A"), textPrimary: Color(hex: "E8E0E0"), bgSecondary: Color(hex: "1A1313"), isLight: false),
        ThemePreview(id: "carbon", name: "Carbon", accent: Color(hex: "8B5CF6"), bgPrimary: Color(hex: "0D0A12"), textPrimary: Color(hex: "E0DCE8"), bgSecondary: Color(hex: "16131E"), isLight: false),
        ThemePreview(id: "graphite", name: "Graphite", accent: Color(hex: "14B8A6"), bgPrimary: Color(hex: "0A0F0F"), textPrimary: Color(hex: "D8E4E4"), bgSecondary: Color(hex: "131A1A"), isLight: false),
        ThemePreview(id: "paper", name: "Paper", accent: Color(hex: "EA580C"), bgPrimary: Color(hex: "FAFAF9"), textPrimary: Color(hex: "1C1917"), bgSecondary: Color(hex: "F0EFEE"), isLight: true),
        ThemePreview(id: "snow", name: "Snow", accent: Color(hex: "2563EB"), bgPrimary: Color(hex: "FAFBFF"), textPrimary: Color(hex: "111827"), bgSecondary: Color(hex: "EFF1F5"), isLight: true)
    ]
}

// MARK: - Theme Picker View

struct ThemePickerView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.theme) private var theme: any AppTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingMD) {
                Text("Choose a theme for ILS. Themes change all colors across the app.")
                    .font(.system(size: theme.fontCaption))
                    .foregroundStyle(theme.textSecondary)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(ThemePreview.all) { preview in
                        themeCard(preview)
                    }
                }
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingSM)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Theme")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Theme Card

    @ViewBuilder
    private func themeCard(_ preview: ThemePreview) -> some View {
        let isActive = themeManager.currentTheme.id == preview.id
        let isAvailable = themeManager.availableThemes.contains(where: { $0.id == preview.id })

        Button {
            if isAvailable {
                if reduceMotion {
                    themeManager.setTheme(preview.id)
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        themeManager.setTheme(preview.id)
                    }
                }
            }
        } label: {
            VStack(spacing: 0) {
                // Preview area — simulated mini-screen
                ZStack {
                    // Background
                    preview.bgPrimary

                    VStack(spacing: 6) {
                        // Simulated title bar
                        HStack {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(preview.textPrimary)
                                .frame(width: 40, height: 6)
                            Spacer()
                            Circle()
                                .fill(preview.accent)
                                .frame(width: 8, height: 8)
                        }
                        .padding(.horizontal, 10)

                        // Simulated card
                        RoundedRectangle(cornerRadius: 4)
                            .fill(preview.bgSecondary)
                            .frame(height: 24)
                            .padding(.horizontal, 10)

                        // Simulated list rows
                        VStack(spacing: 3) {
                            ForEach(0..<3, id: \.self) { _ in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(preview.accent.opacity(0.6))
                                        .frame(width: 5, height: 5)
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .fill(preview.textPrimary.opacity(0.4))
                                        .frame(height: 4)
                                }
                                .padding(.horizontal, 10)
                            }
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.top, 10)

                    // Active checkmark overlay
                    if isActive {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(preview.accent)
                                    .background(
                                        Circle()
                                            .fill(preview.bgPrimary)
                                            .frame(width: 18, height: 18)
                                    )
                            }
                            Spacer()
                        }
                        .padding(6)
                    }
                }
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

                // Color swatches + name
                VStack(spacing: 6) {
                    // 4 color swatches
                    HStack(spacing: 4) {
                        swatchCircle(preview.bgPrimary, border: preview.isLight)
                        swatchCircle(preview.accent, border: false)
                        swatchCircle(preview.textPrimary, border: preview.isLight)
                        swatchCircle(preview.bgSecondary, border: preview.isLight)
                    }

                    // Theme name
                    Text(preview.name)
                        .font(.system(size: theme.fontCaption, weight: isActive ? .semibold : .regular))
                        .foregroundStyle(isActive ? theme.accent : theme.textPrimary)
                        .lineLimit(1)

                }
                .padding(.vertical, theme.spacingSM)
            }
            .modifier(GlassCard())
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .stroke(isActive ? theme.accent : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(preview.name) theme\(isActive ? ", active" : "")")
    }

    @ViewBuilder
    private func swatchCircle(_ color: Color, border: Bool) -> some View {
        Circle()
            .fill(color)
            .frame(width: 14, height: 14)
            .overlay(
                Circle()
                    .stroke(border ? theme.border : Color.clear, lineWidth: 0.5)
            )
    }
}

#Preview {
    NavigationStack {
        ThemePickerView()
            .environmentObject(ThemeManager())
            .environment(\.theme, ObsidianTheme())
    }
}
