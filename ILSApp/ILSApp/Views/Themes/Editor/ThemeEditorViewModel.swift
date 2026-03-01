import SwiftUI
import Observation
import ILSShared

// MARK: - Color Palette Enum

enum ColorPalette: String, CaseIterable, Identifiable {
    case none = "Custom"
    case material = "Material Design"
    case tailwind = "Tailwind CSS"
    case native = "iOS Native"
    case nord = "Nord"
    case dracula = "Dracula"
    case solarized = "Solarized"

    var id: String { rawValue }
}

// MARK: - ThemeEditorViewModel

@MainActor
@Observable
class ThemeEditorViewModel {

    // MARK: - Source Theme

    let theme: CustomTheme?
    let isNewTheme: Bool

    // MARK: - Metadata Properties

    var name: String
    var description: String
    var author: String
    var version: String

    // MARK: - Color Token Properties

    var accent: Color
    var background: Color
    var secondaryBackground: Color
    var tertiaryBackground: Color
    var primaryText: Color
    var secondaryText: Color
    var tertiaryText: Color
    var success: Color
    var warning: Color
    var error: Color
    var info: Color
    var userBubble: Color
    var assistantBubble: Color
    var border: Color
    var separator: Color
    var overlay: Color
    var highlight: Color

    // MARK: - Typography Token Properties

    var primaryFontFamily: String
    var monospacedFontFamily: String
    var titleSize: String
    var headlineSize: String
    var bodySize: String
    var captionSize: String
    var footnoteSize: String
    var titleWeight: String
    var headlineWeight: String
    var bodyWeight: String
    var titleLineHeight: String
    var bodyLineHeight: String
    var captionLineHeight: String

    // MARK: - Spacing Token Properties

    var spacingXS: String
    var spacingS: String
    var spacingM: String
    var spacingL: String
    var spacingXL: String
    var spacingXXL: String
    var buttonPaddingHorizontal: String
    var buttonPaddingVertical: String
    var cardPadding: String
    var listItemSpacing: String

    // MARK: - Corner Radius Token Properties

    var cornerRadiusS: String
    var cornerRadiusM: String
    var cornerRadiusL: String
    var cornerRadiusXL: String
    var buttonCornerRadius: String
    var cardCornerRadius: String
    var inputCornerRadius: String
    var bubbleCornerRadius: String

    // MARK: - Shadow Token Properties

    var shadowLightColor: Color
    var shadowLightOpacity: String
    var shadowLightRadius: String
    var shadowLightOffsetX: String
    var shadowLightOffsetY: String
    var shadowMediumColor: Color
    var shadowMediumOpacity: String
    var shadowMediumRadius: String
    var shadowMediumOffsetX: String
    var shadowMediumOffsetY: String
    var shadowHeavyColor: Color
    var shadowHeavyOpacity: String
    var shadowHeavyRadius: String
    var shadowHeavyOffsetX: String
    var shadowHeavyOffsetY: String

    // MARK: - MeshGradient Properties

    var meshGradientEnabled: Bool
    var meshGradientAnimated: Bool
    var meshGradientColor0: Color
    var meshGradientColor1: Color
    var meshGradientColor2: Color
    var meshGradientColor3: Color
    var meshGradientColor4: Color
    var meshGradientColor5: Color
    var meshGradientColor6: Color
    var meshGradientColor7: Color
    var meshGradientColor8: Color

    // MARK: - UI State Properties

    var isSaving = false
    var showSaveError = false
    var saveErrorMessage = ""
    var expandedSections: Set<String> = []
    var showShareSheet = false
    var exportURL: URL?
    var selectedPalette: ColorPalette = .none
    var didSave = false

    // MARK: - Init

    init(theme: CustomTheme? = nil) {
        self.theme = theme
        self.isNewTheme = theme == nil

        // Initialize metadata
        name = theme?.name ?? ""
        description = theme?.description ?? ""
        author = theme?.author ?? ""
        version = theme?.version ?? "1.0.0"

        // Initialize color tokens
        let hexToColor: (String?) -> Color = { hex in
            guard let hex = hex, !hex.isEmpty else { return .gray }
            let hexString = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            var int: UInt64 = 0
            Scanner(string: hexString).scanHexInt64(&int)

            let a, r, g, b: UInt64
            switch hexString.count {
            case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
            case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
            case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
            default: return .gray
            }

            return Color(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
        }

        accent = hexToColor(theme?.colors?.accent)
        background = hexToColor(theme?.colors?.background)
        secondaryBackground = hexToColor(theme?.colors?.secondaryBackground)
        tertiaryBackground = hexToColor(theme?.colors?.tertiaryBackground)
        primaryText = hexToColor(theme?.colors?.primaryText)
        secondaryText = hexToColor(theme?.colors?.secondaryText)
        tertiaryText = hexToColor(theme?.colors?.tertiaryText)
        success = hexToColor(theme?.colors?.success)
        warning = hexToColor(theme?.colors?.warning)
        error = hexToColor(theme?.colors?.error)
        info = hexToColor(theme?.colors?.info)
        userBubble = hexToColor(theme?.colors?.userBubble)
        assistantBubble = hexToColor(theme?.colors?.assistantBubble)
        border = hexToColor(theme?.colors?.border)
        separator = hexToColor(theme?.colors?.separator)
        overlay = hexToColor(theme?.colors?.overlay)
        highlight = hexToColor(theme?.colors?.highlight)

        // Initialize typography tokens
        primaryFontFamily = theme?.typography?.primaryFontFamily ?? ""
        monospacedFontFamily = theme?.typography?.monospacedFontFamily ?? ""
        titleSize = theme?.typography?.titleSize?.description ?? ""
        headlineSize = theme?.typography?.headlineSize?.description ?? ""
        bodySize = theme?.typography?.bodySize?.description ?? ""
        captionSize = theme?.typography?.captionSize?.description ?? ""
        footnoteSize = theme?.typography?.footnoteSize?.description ?? ""
        titleWeight = theme?.typography?.titleWeight ?? ""
        headlineWeight = theme?.typography?.headlineWeight ?? ""
        bodyWeight = theme?.typography?.bodyWeight ?? ""
        titleLineHeight = theme?.typography?.titleLineHeight?.description ?? ""
        bodyLineHeight = theme?.typography?.bodyLineHeight?.description ?? ""
        captionLineHeight = theme?.typography?.captionLineHeight?.description ?? ""

        // Initialize spacing tokens
        spacingXS = theme?.spacing?.spacingXS?.description ?? ""
        spacingS = theme?.spacing?.spacingS?.description ?? ""
        spacingM = theme?.spacing?.spacingM?.description ?? ""
        spacingL = theme?.spacing?.spacingL?.description ?? ""
        spacingXL = theme?.spacing?.spacingXL?.description ?? ""
        spacingXXL = theme?.spacing?.spacingXXL?.description ?? ""
        buttonPaddingHorizontal = theme?.spacing?.buttonPaddingHorizontal?.description ?? ""
        buttonPaddingVertical = theme?.spacing?.buttonPaddingVertical?.description ?? ""
        cardPadding = theme?.spacing?.cardPadding?.description ?? ""
        listItemSpacing = theme?.spacing?.listItemSpacing?.description ?? ""

        // Initialize corner radius tokens
        cornerRadiusS = theme?.cornerRadius?.cornerRadiusS?.description ?? ""
        cornerRadiusM = theme?.cornerRadius?.cornerRadiusM?.description ?? ""
        cornerRadiusL = theme?.cornerRadius?.cornerRadiusL?.description ?? ""
        cornerRadiusXL = theme?.cornerRadius?.cornerRadiusXL?.description ?? ""
        buttonCornerRadius = theme?.cornerRadius?.buttonCornerRadius?.description ?? ""
        cardCornerRadius = theme?.cornerRadius?.cardCornerRadius?.description ?? ""
        inputCornerRadius = theme?.cornerRadius?.inputCornerRadius?.description ?? ""
        bubbleCornerRadius = theme?.cornerRadius?.bubbleCornerRadius?.description ?? ""

        // Initialize shadow tokens
        shadowLightColor = hexToColor(theme?.shadows?.shadowLightColor)
        shadowLightOpacity = theme?.shadows?.shadowLightOpacity?.description ?? ""
        shadowLightRadius = theme?.shadows?.shadowLightRadius?.description ?? ""
        shadowLightOffsetX = theme?.shadows?.shadowLightOffsetX?.description ?? ""
        shadowLightOffsetY = theme?.shadows?.shadowLightOffsetY?.description ?? ""
        shadowMediumColor = hexToColor(theme?.shadows?.shadowMediumColor)
        shadowMediumOpacity = theme?.shadows?.shadowMediumOpacity?.description ?? ""
        shadowMediumRadius = theme?.shadows?.shadowMediumRadius?.description ?? ""
        shadowMediumOffsetX = theme?.shadows?.shadowMediumOffsetX?.description ?? ""
        shadowMediumOffsetY = theme?.shadows?.shadowMediumOffsetY?.description ?? ""
        shadowHeavyColor = hexToColor(theme?.shadows?.shadowHeavyColor)
        shadowHeavyOpacity = theme?.shadows?.shadowHeavyOpacity?.description ?? ""
        shadowHeavyRadius = theme?.shadows?.shadowHeavyRadius?.description ?? ""
        shadowHeavyOffsetX = theme?.shadows?.shadowHeavyOffsetX?.description ?? ""
        shadowHeavyOffsetY = theme?.shadows?.shadowHeavyOffsetY?.description ?? ""

        // Initialize mesh gradient properties
        meshGradientEnabled = theme?.meshGradient?.enabled ?? false
        meshGradientAnimated = theme?.meshGradient?.animated ?? false
        let meshColors = theme?.meshGradient?.colors ?? []
        meshGradientColor0 = hexToColor(meshColors.count > 0 ? meshColors[0] : nil)
        meshGradientColor1 = hexToColor(meshColors.count > 1 ? meshColors[1] : nil)
        meshGradientColor2 = hexToColor(meshColors.count > 2 ? meshColors[2] : nil)
        meshGradientColor3 = hexToColor(meshColors.count > 3 ? meshColors[3] : nil)
        meshGradientColor4 = hexToColor(meshColors.count > 4 ? meshColors[4] : nil)
        meshGradientColor5 = hexToColor(meshColors.count > 5 ? meshColors[5] : nil)
        meshGradientColor6 = hexToColor(meshColors.count > 6 ? meshColors[6] : nil)
        meshGradientColor7 = hexToColor(meshColors.count > 7 ? meshColors[7] : nil)
        meshGradientColor8 = hexToColor(meshColors.count > 8 ? meshColors[8] : nil)
    }

    // MARK: - Computed Properties

    /// Builds a preview theme from current state values
    var previewTheme: CustomTheme {
        CustomTheme(
            id: theme?.id ?? UUID(),
            name: name.isEmpty ? "Preview" : name,
            description: description.isEmpty ? nil : description,
            author: author.isEmpty ? nil : author,
            version: version.isEmpty ? "1.0.0" : version,
            createdAt: theme?.createdAt ?? Date(),
            updatedAt: theme?.updatedAt ?? Date(),
            colors: ColorTokens(
                accent: hexFromColor(accent),
                background: hexFromColor(background),
                secondaryBackground: hexFromColor(secondaryBackground),
                tertiaryBackground: hexFromColor(tertiaryBackground),
                primaryText: hexFromColor(primaryText),
                secondaryText: hexFromColor(secondaryText),
                tertiaryText: hexFromColor(tertiaryText),
                success: hexFromColor(success),
                warning: hexFromColor(warning),
                error: hexFromColor(error),
                info: hexFromColor(info),
                userBubble: hexFromColor(userBubble),
                assistantBubble: hexFromColor(assistantBubble),
                border: hexFromColor(border),
                separator: hexFromColor(separator),
                overlay: hexFromColor(overlay),
                highlight: hexFromColor(highlight)
            ),
            typography: TypographyTokens(
                primaryFontFamily: primaryFontFamily.isEmpty ? nil : primaryFontFamily,
                monospacedFontFamily: monospacedFontFamily.isEmpty ? nil : monospacedFontFamily,
                titleSize: Double(titleSize),
                headlineSize: Double(headlineSize),
                bodySize: Double(bodySize),
                captionSize: Double(captionSize),
                footnoteSize: Double(footnoteSize),
                titleWeight: titleWeight.isEmpty ? nil : titleWeight,
                headlineWeight: headlineWeight.isEmpty ? nil : headlineWeight,
                bodyWeight: bodyWeight.isEmpty ? nil : bodyWeight,
                titleLineHeight: Double(titleLineHeight),
                bodyLineHeight: Double(bodyLineHeight),
                captionLineHeight: Double(captionLineHeight)
            ),
            spacing: SpacingTokens(
                spacingXS: Double(spacingXS),
                spacingS: Double(spacingS),
                spacingM: Double(spacingM),
                spacingL: Double(spacingL),
                spacingXL: Double(spacingXL),
                spacingXXL: Double(spacingXXL),
                buttonPaddingHorizontal: Double(buttonPaddingHorizontal),
                buttonPaddingVertical: Double(buttonPaddingVertical),
                cardPadding: Double(cardPadding),
                listItemSpacing: Double(listItemSpacing)
            ),
            cornerRadius: CornerRadiusTokens(
                cornerRadiusS: Double(cornerRadiusS),
                cornerRadiusM: Double(cornerRadiusM),
                cornerRadiusL: Double(cornerRadiusL),
                cornerRadiusXL: Double(cornerRadiusXL),
                buttonCornerRadius: Double(buttonCornerRadius),
                cardCornerRadius: Double(cardCornerRadius),
                inputCornerRadius: Double(inputCornerRadius),
                bubbleCornerRadius: Double(bubbleCornerRadius)
            ),
            shadows: ShadowTokens(
                shadowLightColor: hexFromColor(shadowLightColor),
                shadowLightOpacity: Double(shadowLightOpacity),
                shadowLightRadius: Double(shadowLightRadius),
                shadowLightOffsetX: Double(shadowLightOffsetX),
                shadowLightOffsetY: Double(shadowLightOffsetY),
                shadowMediumColor: hexFromColor(shadowMediumColor),
                shadowMediumOpacity: Double(shadowMediumOpacity),
                shadowMediumRadius: Double(shadowMediumRadius),
                shadowMediumOffsetX: Double(shadowMediumOffsetX),
                shadowMediumOffsetY: Double(shadowMediumOffsetY),
                shadowHeavyColor: hexFromColor(shadowHeavyColor),
                shadowHeavyOpacity: Double(shadowHeavyOpacity),
                shadowHeavyRadius: Double(shadowHeavyRadius),
                shadowHeavyOffsetX: Double(shadowHeavyOffsetX),
                shadowHeavyOffsetY: Double(shadowHeavyOffsetY)
            ),
            meshGradient: meshGradientEnabled ? MeshGradientConfig(
                enabled: true,
                colors: meshGradientColorHexArray,
                animated: meshGradientAnimated
            ) : nil
        )
    }

    /// Returns the 9 mesh gradient colors as hex strings for the 3x3 grid.
    var meshGradientColorHexArray: [String] {
        [
            hexFromColor(meshGradientColor0),
            hexFromColor(meshGradientColor1),
            hexFromColor(meshGradientColor2),
            hexFromColor(meshGradientColor3),
            hexFromColor(meshGradientColor4),
            hexFromColor(meshGradientColor5),
            hexFromColor(meshGradientColor6),
            hexFromColor(meshGradientColor7),
            hexFromColor(meshGradientColor8)
        ]
    }

    // MARK: - Palette Application

    /// Applies a color palette to all color tokens
    func applyPalette(_ palette: ColorPalette) {
        switch palette {
        case .none:
            break // Keep custom colors

        case .material:
            accent = MaterialPalette.accent
            background = MaterialPalette.background
            secondaryBackground = MaterialPalette.surface
            tertiaryBackground = MaterialPalette.surface.opacity(0.8)
            primaryText = MaterialPalette.onBackground
            secondaryText = MaterialPalette.onBackground.opacity(0.7)
            tertiaryText = MaterialPalette.onBackground.opacity(0.5)
            success = MaterialPalette.success
            warning = MaterialPalette.warning
            error = MaterialPalette.error
            info = MaterialPalette.info
            userBubble = MaterialPalette.primary.opacity(0.15)
            assistantBubble = MaterialPalette.surface
            border = MaterialPalette.onBackground.opacity(0.2)
            separator = MaterialPalette.onBackground.opacity(0.1)
            overlay = Color.black.opacity(0.3)
            highlight = MaterialPalette.secondary.opacity(0.2)

        case .tailwind:
            accent = TailwindPalette.accent
            background = Color.white
            secondaryBackground = TailwindPalette.gray500.opacity(0.1)
            tertiaryBackground = TailwindPalette.gray500.opacity(0.05)
            primaryText = TailwindPalette.neutral500
            secondaryText = TailwindPalette.gray500.opacity(0.7)
            tertiaryText = TailwindPalette.gray500.opacity(0.5)
            success = TailwindPalette.success
            warning = TailwindPalette.warning
            error = TailwindPalette.error
            info = TailwindPalette.info
            userBubble = TailwindPalette.primary.opacity(0.15)
            assistantBubble = TailwindPalette.gray500.opacity(0.1)
            border = TailwindPalette.neutral500.opacity(0.2)
            separator = TailwindPalette.neutral500.opacity(0.1)
            overlay = Color.black.opacity(0.3)
            highlight = TailwindPalette.violet500.opacity(0.2)

        case .native:
            accent = NativePalette.accent
            background = NativePalette.background
            secondaryBackground = NativePalette.secondaryBackground
            tertiaryBackground = NativePalette.tertiaryBackground
            primaryText = NativePalette.primaryText
            secondaryText = NativePalette.secondaryText
            tertiaryText = NativePalette.tertiaryText
            success = NativePalette.success
            warning = NativePalette.warning
            error = NativePalette.error
            info = NativePalette.info
            userBubble = NativePalette.primary.opacity(0.15)
            assistantBubble = NativePalette.secondaryBackground
            border = NativePalette.secondaryText.opacity(0.2)
            separator = NativePalette.tertiaryText.opacity(0.1)
            overlay = Color.black.opacity(0.3)
            highlight = NativePalette.accent.opacity(0.2)

        case .nord:
            accent = NordPalette.accent
            background = NordPalette.background
            secondaryBackground = NordPalette.surface
            tertiaryBackground = NordPalette.nord2
            primaryText = NordPalette.text
            secondaryText = NordPalette.text.opacity(0.7)
            tertiaryText = NordPalette.text.opacity(0.5)
            success = NordPalette.success
            warning = NordPalette.warning
            error = NordPalette.error
            info = NordPalette.info
            userBubble = NordPalette.primary.opacity(0.3)
            assistantBubble = NordPalette.surface
            border = NordPalette.nord3
            separator = NordPalette.nord3.opacity(0.5)
            overlay = Color.black.opacity(0.5)
            highlight = NordPalette.nord8.opacity(0.3)

        case .dracula:
            accent = DraculaPalette.accent
            background = DraculaPalette.background
            secondaryBackground = DraculaPalette.currentLine
            tertiaryBackground = DraculaPalette.selection
            primaryText = DraculaPalette.text
            secondaryText = DraculaPalette.text.opacity(0.7)
            tertiaryText = DraculaPalette.comment
            success = DraculaPalette.success
            warning = DraculaPalette.warning
            error = DraculaPalette.error
            info = DraculaPalette.info
            userBubble = DraculaPalette.purple.opacity(0.2)
            assistantBubble = DraculaPalette.currentLine
            border = DraculaPalette.comment
            separator = DraculaPalette.comment.opacity(0.5)
            overlay = Color.black.opacity(0.6)
            highlight = DraculaPalette.cyan.opacity(0.2)

        case .solarized:
            accent = SolarizedPalette.accent
            background = SolarizedPalette.background
            secondaryBackground = SolarizedPalette.surface
            tertiaryBackground = SolarizedPalette.base01
            primaryText = SolarizedPalette.text
            secondaryText = SolarizedPalette.text.opacity(0.7)
            tertiaryText = SolarizedPalette.base01
            success = SolarizedPalette.success
            warning = SolarizedPalette.warning
            error = SolarizedPalette.error
            info = SolarizedPalette.info
            userBubble = SolarizedPalette.primary.opacity(0.2)
            assistantBubble = SolarizedPalette.surface
            border = SolarizedPalette.base01
            separator = SolarizedPalette.base01.opacity(0.5)
            overlay = Color.black.opacity(0.5)
            highlight = SolarizedPalette.violet.opacity(0.2)
        }
    }

    // MARK: - Save Theme

    func saveTheme(viewModel: ThemesViewModel) async {
        guard !name.isEmpty else { return }

        isSaving = true

        // Build color tokens
        let colors = ColorTokens(
            accent: hexFromColor(accent),
            background: hexFromColor(background),
            secondaryBackground: hexFromColor(secondaryBackground),
            tertiaryBackground: hexFromColor(tertiaryBackground),
            primaryText: hexFromColor(primaryText),
            secondaryText: hexFromColor(secondaryText),
            tertiaryText: hexFromColor(tertiaryText),
            success: hexFromColor(success),
            warning: hexFromColor(warning),
            error: hexFromColor(error),
            info: hexFromColor(info),
            userBubble: hexFromColor(userBubble),
            assistantBubble: hexFromColor(assistantBubble),
            border: hexFromColor(border),
            separator: hexFromColor(separator),
            overlay: hexFromColor(overlay),
            highlight: hexFromColor(highlight)
        )

        // Build typography tokens
        let typography = TypographyTokens(
            primaryFontFamily: primaryFontFamily.isEmpty ? nil : primaryFontFamily,
            monospacedFontFamily: monospacedFontFamily.isEmpty ? nil : monospacedFontFamily,
            titleSize: Double(titleSize),
            headlineSize: Double(headlineSize),
            bodySize: Double(bodySize),
            captionSize: Double(captionSize),
            footnoteSize: Double(footnoteSize),
            titleWeight: titleWeight.isEmpty ? nil : titleWeight,
            headlineWeight: headlineWeight.isEmpty ? nil : headlineWeight,
            bodyWeight: bodyWeight.isEmpty ? nil : bodyWeight,
            titleLineHeight: Double(titleLineHeight),
            bodyLineHeight: Double(bodyLineHeight),
            captionLineHeight: Double(captionLineHeight)
        )

        // Build spacing tokens
        let spacing = SpacingTokens(
            spacingXS: Double(spacingXS),
            spacingS: Double(spacingS),
            spacingM: Double(spacingM),
            spacingL: Double(spacingL),
            spacingXL: Double(spacingXL),
            spacingXXL: Double(spacingXXL),
            buttonPaddingHorizontal: Double(buttonPaddingHorizontal),
            buttonPaddingVertical: Double(buttonPaddingVertical),
            cardPadding: Double(cardPadding),
            listItemSpacing: Double(listItemSpacing)
        )

        // Build corner radius tokens
        let cornerRadius = CornerRadiusTokens(
            cornerRadiusS: Double(cornerRadiusS),
            cornerRadiusM: Double(cornerRadiusM),
            cornerRadiusL: Double(cornerRadiusL),
            cornerRadiusXL: Double(cornerRadiusXL),
            buttonCornerRadius: Double(buttonCornerRadius),
            cardCornerRadius: Double(cardCornerRadius),
            inputCornerRadius: Double(inputCornerRadius),
            bubbleCornerRadius: Double(bubbleCornerRadius)
        )

        // Build shadow tokens
        let shadows = ShadowTokens(
            shadowLightColor: hexFromColor(shadowLightColor),
            shadowLightOpacity: Double(shadowLightOpacity),
            shadowLightRadius: Double(shadowLightRadius),
            shadowLightOffsetX: Double(shadowLightOffsetX),
            shadowLightOffsetY: Double(shadowLightOffsetY),
            shadowMediumColor: hexFromColor(shadowMediumColor),
            shadowMediumOpacity: Double(shadowMediumOpacity),
            shadowMediumRadius: Double(shadowMediumRadius),
            shadowMediumOffsetX: Double(shadowMediumOffsetX),
            shadowMediumOffsetY: Double(shadowMediumOffsetY),
            shadowHeavyColor: hexFromColor(shadowHeavyColor),
            shadowHeavyOpacity: Double(shadowHeavyOpacity),
            shadowHeavyRadius: Double(shadowHeavyRadius),
            shadowHeavyOffsetX: Double(shadowHeavyOffsetX),
            shadowHeavyOffsetY: Double(shadowHeavyOffsetY)
        )

        // Build mesh gradient config
        let meshGradient: MeshGradientConfig? = meshGradientEnabled ? MeshGradientConfig(
            enabled: true,
            colors: meshGradientColorHexArray,
            animated: meshGradientAnimated
        ) : nil

        let result: CustomTheme?
        if let theme = theme {
            // Update existing theme
            result = await viewModel.updateTheme(
                theme,
                name: name,
                description: description.isEmpty ? nil : description,
                author: author.isEmpty ? nil : author,
                version: version.isEmpty ? nil : version,
                colors: colors,
                typography: typography,
                spacing: spacing,
                cornerRadius: cornerRadius,
                shadows: shadows,
                meshGradient: meshGradient
            )
        } else {
            // Create new theme
            result = await viewModel.createTheme(
                name: name,
                description: description.isEmpty ? nil : description,
                author: author.isEmpty ? nil : author,
                version: version.isEmpty ? nil : version,
                colors: colors,
                typography: typography,
                spacing: spacing,
                cornerRadius: cornerRadius,
                shadows: shadows,
                meshGradient: meshGradient
            )
        }

        isSaving = false

        if result != nil {
            didSave = true
        } else if let error = viewModel.error {
            saveErrorMessage = error.localizedDescription
            showSaveError = true
        }
    }

    // MARK: - Export Theme

    private static let themeEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    func exportTheme() {
        do {
            let jsonData = try Self.themeEncoder.encode(previewTheme)

            // Write to Caches (survives backgrounding, unlike tmp/)
            let fileName = "\(name.isEmpty ? "theme" : name.replacingOccurrences(of: " ", with: "_")).json"
            let exportDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
                .appendingPathComponent("ThemeExports", isDirectory: true)
            try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
            // STOR-HIGH: Exclude export cache from iCloud/iTunes backup
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            var mutableExportDir = exportDir
            try? mutableExportDir.setResourceValues(resourceValues)
            let fileURL = exportDir.appendingPathComponent(fileName)

            try jsonData.write(to: fileURL)

            exportURL = fileURL
            showShareSheet = true
        } catch {
            saveErrorMessage = "Failed to export theme: \(error.localizedDescription)"
            showSaveError = true
        }
    }

    // MARK: - Color Helpers

    func colorFromHex(_ hex: String?) -> Color {
        guard let hex = hex, !hex.isEmpty else {
            return .gray
        }

        let hexString = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hexString.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return .gray
        }

        return Color(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func hexFromColor(_ color: Color) -> String {
        guard let components = color.cgColor?.components else {
            return "#808080"
        }

        let r = components.count > 0 ? components[0] : 0
        let g = components.count > 1 ? components[1] : 0
        let b = components.count > 2 ? components[2] : 0

        return String(format: "#%02X%02X%02X",
                      Int(r * 255),
                      Int(g * 255),
                      Int(b * 255))
    }
}
