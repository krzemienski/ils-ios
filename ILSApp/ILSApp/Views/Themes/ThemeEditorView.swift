import SwiftUI
import ILSShared

struct ThemeEditorView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: ThemesViewModel

    let theme: CustomTheme?
    let isNewTheme: Bool

    // MARK: - Metadata State
    @State private var name: String
    @State private var description: String
    @State private var author: String
    @State private var version: String

    // MARK: - Color Tokens State
    @State private var accent: Color
    @State private var background: Color
    @State private var secondaryBackground: Color
    @State private var tertiaryBackground: Color
    @State private var primaryText: Color
    @State private var secondaryText: Color
    @State private var tertiaryText: Color
    @State private var success: Color
    @State private var warning: Color
    @State private var error: Color
    @State private var info: Color
    @State private var userBubble: Color
    @State private var assistantBubble: Color
    @State private var border: Color
    @State private var separator: Color
    @State private var overlay: Color
    @State private var highlight: Color

    // MARK: - Typography Tokens State
    @State private var primaryFontFamily: String
    @State private var monospacedFontFamily: String
    @State private var titleSize: String
    @State private var headlineSize: String
    @State private var bodySize: String
    @State private var captionSize: String
    @State private var footnoteSize: String
    @State private var titleWeight: String
    @State private var headlineWeight: String
    @State private var bodyWeight: String
    @State private var titleLineHeight: String
    @State private var bodyLineHeight: String
    @State private var captionLineHeight: String

    // MARK: - Spacing Tokens State
    @State private var spacingXS: String
    @State private var spacingS: String
    @State private var spacingM: String
    @State private var spacingL: String
    @State private var spacingXL: String
    @State private var spacingXXL: String
    @State private var buttonPaddingHorizontal: String
    @State private var buttonPaddingVertical: String
    @State private var cardPadding: String
    @State private var listItemSpacing: String

    // MARK: - Corner Radius Tokens State
    @State private var cornerRadiusS: String
    @State private var cornerRadiusM: String
    @State private var cornerRadiusL: String
    @State private var cornerRadiusXL: String
    @State private var buttonCornerRadius: String
    @State private var cardCornerRadius: String
    @State private var inputCornerRadius: String
    @State private var bubbleCornerRadius: String

    // MARK: - Shadow Tokens State
    @State private var shadowLightColor: Color
    @State private var shadowLightOpacity: String
    @State private var shadowLightRadius: String
    @State private var shadowLightOffsetX: String
    @State private var shadowLightOffsetY: String
    @State private var shadowMediumColor: Color
    @State private var shadowMediumOpacity: String
    @State private var shadowMediumRadius: String
    @State private var shadowMediumOffsetX: String
    @State private var shadowMediumOffsetY: String
    @State private var shadowHeavyColor: Color
    @State private var shadowHeavyOpacity: String
    @State private var shadowHeavyRadius: String
    @State private var shadowHeavyOffsetX: String
    @State private var shadowHeavyOffsetY: String

    // MARK: - UI State
    @State private var isSaving = false
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""
    @State private var expandedSections: Set<String> = []
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    @State private var selectedPalette: ColorPalette = .none

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

    init(theme: CustomTheme? = nil) {
        self.theme = theme
        self.isNewTheme = theme == nil

        // Initialize metadata
        _name = State(initialValue: theme?.name ?? "")
        _description = State(initialValue: theme?.description ?? "")
        _author = State(initialValue: theme?.author ?? "")
        _version = State(initialValue: theme?.version ?? "1.0.0")

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

        _accent = State(initialValue: hexToColor(theme?.colors?.accent))
        _background = State(initialValue: hexToColor(theme?.colors?.background))
        _secondaryBackground = State(initialValue: hexToColor(theme?.colors?.secondaryBackground))
        _tertiaryBackground = State(initialValue: hexToColor(theme?.colors?.tertiaryBackground))
        _primaryText = State(initialValue: hexToColor(theme?.colors?.primaryText))
        _secondaryText = State(initialValue: hexToColor(theme?.colors?.secondaryText))
        _tertiaryText = State(initialValue: hexToColor(theme?.colors?.tertiaryText))
        _success = State(initialValue: hexToColor(theme?.colors?.success))
        _warning = State(initialValue: hexToColor(theme?.colors?.warning))
        _error = State(initialValue: hexToColor(theme?.colors?.error))
        _info = State(initialValue: hexToColor(theme?.colors?.info))
        _userBubble = State(initialValue: hexToColor(theme?.colors?.userBubble))
        _assistantBubble = State(initialValue: hexToColor(theme?.colors?.assistantBubble))
        _border = State(initialValue: hexToColor(theme?.colors?.border))
        _separator = State(initialValue: hexToColor(theme?.colors?.separator))
        _overlay = State(initialValue: hexToColor(theme?.colors?.overlay))
        _highlight = State(initialValue: hexToColor(theme?.colors?.highlight))

        // Initialize typography tokens
        _primaryFontFamily = State(initialValue: theme?.typography?.primaryFontFamily ?? "")
        _monospacedFontFamily = State(initialValue: theme?.typography?.monospacedFontFamily ?? "")
        _titleSize = State(initialValue: theme?.typography?.titleSize?.description ?? "")
        _headlineSize = State(initialValue: theme?.typography?.headlineSize?.description ?? "")
        _bodySize = State(initialValue: theme?.typography?.bodySize?.description ?? "")
        _captionSize = State(initialValue: theme?.typography?.captionSize?.description ?? "")
        _footnoteSize = State(initialValue: theme?.typography?.footnoteSize?.description ?? "")
        _titleWeight = State(initialValue: theme?.typography?.titleWeight ?? "")
        _headlineWeight = State(initialValue: theme?.typography?.headlineWeight ?? "")
        _bodyWeight = State(initialValue: theme?.typography?.bodyWeight ?? "")
        _titleLineHeight = State(initialValue: theme?.typography?.titleLineHeight?.description ?? "")
        _bodyLineHeight = State(initialValue: theme?.typography?.bodyLineHeight?.description ?? "")
        _captionLineHeight = State(initialValue: theme?.typography?.captionLineHeight?.description ?? "")

        // Initialize spacing tokens
        _spacingXS = State(initialValue: theme?.spacing?.spacingXS?.description ?? "")
        _spacingS = State(initialValue: theme?.spacing?.spacingS?.description ?? "")
        _spacingM = State(initialValue: theme?.spacing?.spacingM?.description ?? "")
        _spacingL = State(initialValue: theme?.spacing?.spacingL?.description ?? "")
        _spacingXL = State(initialValue: theme?.spacing?.spacingXL?.description ?? "")
        _spacingXXL = State(initialValue: theme?.spacing?.spacingXXL?.description ?? "")
        _buttonPaddingHorizontal = State(initialValue: theme?.spacing?.buttonPaddingHorizontal?.description ?? "")
        _buttonPaddingVertical = State(initialValue: theme?.spacing?.buttonPaddingVertical?.description ?? "")
        _cardPadding = State(initialValue: theme?.spacing?.cardPadding?.description ?? "")
        _listItemSpacing = State(initialValue: theme?.spacing?.listItemSpacing?.description ?? "")

        // Initialize corner radius tokens
        _cornerRadiusS = State(initialValue: theme?.cornerRadius?.cornerRadiusS?.description ?? "")
        _cornerRadiusM = State(initialValue: theme?.cornerRadius?.cornerRadiusM?.description ?? "")
        _cornerRadiusL = State(initialValue: theme?.cornerRadius?.cornerRadiusL?.description ?? "")
        _cornerRadiusXL = State(initialValue: theme?.cornerRadius?.cornerRadiusXL?.description ?? "")
        _buttonCornerRadius = State(initialValue: theme?.cornerRadius?.buttonCornerRadius?.description ?? "")
        _cardCornerRadius = State(initialValue: theme?.cornerRadius?.cardCornerRadius?.description ?? "")
        _inputCornerRadius = State(initialValue: theme?.cornerRadius?.inputCornerRadius?.description ?? "")
        _bubbleCornerRadius = State(initialValue: theme?.cornerRadius?.bubbleCornerRadius?.description ?? "")

        // Initialize shadow tokens
        _shadowLightColor = State(initialValue: hexToColor(theme?.shadows?.shadowLightColor))
        _shadowLightOpacity = State(initialValue: theme?.shadows?.shadowLightOpacity?.description ?? "")
        _shadowLightRadius = State(initialValue: theme?.shadows?.shadowLightRadius?.description ?? "")
        _shadowLightOffsetX = State(initialValue: theme?.shadows?.shadowLightOffsetX?.description ?? "")
        _shadowLightOffsetY = State(initialValue: theme?.shadows?.shadowLightOffsetY?.description ?? "")
        _shadowMediumColor = State(initialValue: hexToColor(theme?.shadows?.shadowMediumColor))
        _shadowMediumOpacity = State(initialValue: theme?.shadows?.shadowMediumOpacity?.description ?? "")
        _shadowMediumRadius = State(initialValue: theme?.shadows?.shadowMediumRadius?.description ?? "")
        _shadowMediumOffsetX = State(initialValue: theme?.shadows?.shadowMediumOffsetX?.description ?? "")
        _shadowMediumOffsetY = State(initialValue: theme?.shadows?.shadowMediumOffsetY?.description ?? "")
        _shadowHeavyColor = State(initialValue: hexToColor(theme?.shadows?.shadowHeavyColor))
        _shadowHeavyOpacity = State(initialValue: theme?.shadows?.shadowHeavyOpacity?.description ?? "")
        _shadowHeavyRadius = State(initialValue: theme?.shadows?.shadowHeavyRadius?.description ?? "")
        _shadowHeavyOffsetX = State(initialValue: theme?.shadows?.shadowHeavyOffsetX?.description ?? "")
        _shadowHeavyOffsetY = State(initialValue: theme?.shadows?.shadowHeavyOffsetY?.description ?? "")
    }

    // MARK: - Computed Properties

    /// Builds a preview theme from current state values
    private var previewTheme: CustomTheme {
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
            )
        )
    }

    // MARK: - Palette Application

    /// Applies a color palette to all color tokens
    private func applyPalette(_ palette: ColorPalette) {
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

    var body: some View {
        NavigationView {
            TabView {
                // MARK: - Editor Tab
                editorForm
                    .tabItem {
                        Label("Editor", systemImage: "slider.horizontal.3")
                    }

                // MARK: - Preview Tab
                ThemePreviewView(theme: .constant(previewTheme))
                    .tabItem {
                        Label("Preview", systemImage: "eye")
                    }
            }
            .navigationTitle(isNewTheme ? "New Theme" : "Edit Theme")
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        exportTheme()
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .disabled(name.isEmpty)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await saveTheme()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isSaving || name.isEmpty)
                }
            }
            .alert("Save Error", isPresented: $showSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveErrorMessage)
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    // MARK: - Editor Form

    private var editorForm: some View {
        Form {
            // MARK: - Metadata Section
            Section {
                    TextField("Theme Name", text: $name)
                        .autocapitalization(.words)

                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(2...4)

                    TextField("Author (optional)", text: $author)
                        .autocapitalization(.words)

                    TextField("Version", text: $version)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("Theme Information")
                } footer: {
                    Text("Basic information about your custom theme")
                }

                // MARK: - Color Tokens Section
                Section {
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedSections.contains("colors") },
                            set: { isExpanded in
                                if isExpanded {
                                    expandedSections.insert("colors")
                                } else {
                                    expandedSections.remove("colors")
                                }
                            }
                        )
                    ) {
                        // MARK: - Color Palette Picker
                        Picker("Color Palette", selection: $selectedPalette) {
                            ForEach(ColorPalette.allCases) { palette in
                                Text(palette.rawValue).tag(palette)
                            }
                        }
                        .onChange(of: selectedPalette) { _, newValue in
                            applyPalette(newValue)
                        }

                        Divider()
                            .padding(.vertical, 8)

                        Group {
                            ColorPicker("Accent", selection: $accent)
                            ColorPicker("Background", selection: $background)
                            ColorPicker("Secondary Background", selection: $secondaryBackground)
                            ColorPicker("Tertiary Background", selection: $tertiaryBackground)
                        }

                        Group {
                            ColorPicker("Primary Text", selection: $primaryText)
                            ColorPicker("Secondary Text", selection: $secondaryText)
                            ColorPicker("Tertiary Text", selection: $tertiaryText)
                        }

                        Group {
                            ColorPicker("Success", selection: $success)
                            ColorPicker("Warning", selection: $warning)
                            ColorPicker("Error", selection: $error)
                            ColorPicker("Info", selection: $info)
                        }

                        Group {
                            ColorPicker("User Bubble", selection: $userBubble)
                            ColorPicker("Assistant Bubble", selection: $assistantBubble)
                            ColorPicker("Border", selection: $border)
                            ColorPicker("Separator", selection: $separator)
                            ColorPicker("Overlay", selection: $overlay)
                            ColorPicker("Highlight", selection: $highlight)
                        }
                    } label: {
                        Label("Color Tokens (17)", systemImage: "paintpalette")
                    }
                } header: {
                    Text("Colors")
                } footer: {
                    Text("Choose a color palette preset or customize individual colors")
                }

                // MARK: - Typography Tokens Section
                Section {
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedSections.contains("typography") },
                            set: { isExpanded in
                                if isExpanded {
                                    expandedSections.insert("typography")
                                } else {
                                    expandedSections.remove("typography")
                                }
                            }
                        )
                    ) {
                        Group {
                            Picker("Primary Font Family", selection: $primaryFontFamily) {
                                Text("System (Default)").tag("")
                                Text("San Francisco").tag("SF Pro")
                                Text("San Francisco Rounded").tag("SF Pro Rounded")
                                Text("New York").tag("New York")
                                Text("Helvetica").tag("Helvetica")
                                Text("Arial").tag("Arial")
                                Text("Georgia").tag("Georgia")
                                Text("Times New Roman").tag("Times New Roman")
                                Text("Palatino").tag("Palatino")
                                Text("Gill Sans").tag("Gill Sans")
                                Text("Courier").tag("Courier")
                            }

                            Picker("Monospaced Font Family", selection: $monospacedFontFamily) {
                                Text("System Monospaced (Default)").tag("")
                                Text("SF Mono").tag("SF Mono")
                                Text("Menlo").tag("Menlo")
                                Text("Monaco").tag("Monaco")
                                Text("Courier").tag("Courier")
                                Text("Courier New").tag("Courier New")
                            }
                        }

                        Group {
                            TextField("Title Size", text: $titleSize)
                                .keyboardType(.decimalPad)
                            TextField("Headline Size", text: $headlineSize)
                                .keyboardType(.decimalPad)
                            TextField("Body Size", text: $bodySize)
                                .keyboardType(.decimalPad)
                            TextField("Caption Size", text: $captionSize)
                                .keyboardType(.decimalPad)
                            TextField("Footnote Size", text: $footnoteSize)
                                .keyboardType(.decimalPad)
                        }

                        Group {
                            TextField("Title Weight", text: $titleWeight)
                            TextField("Headline Weight", text: $headlineWeight)
                            TextField("Body Weight", text: $bodyWeight)
                        }

                        Group {
                            TextField("Title Line Height", text: $titleLineHeight)
                                .keyboardType(.decimalPad)
                            TextField("Body Line Height", text: $bodyLineHeight)
                                .keyboardType(.decimalPad)
                            TextField("Caption Line Height", text: $captionLineHeight)
                                .keyboardType(.decimalPad)
                        }
                    } label: {
                        Label("Typography Tokens (13)", systemImage: "textformat")
                    }
                } header: {
                    Text("Typography")
                } footer: {
                    Text("Font families, sizes (in points), weights, and line heights")
                }

                // MARK: - Spacing Tokens Section
                Section {
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedSections.contains("spacing") },
                            set: { isExpanded in
                                if isExpanded {
                                    expandedSections.insert("spacing")
                                } else {
                                    expandedSections.remove("spacing")
                                }
                            }
                        )
                    ) {
                        Group {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Spacing XS: \(spacingXS.isEmpty ? "0" : spacingXS) pt")
                                    .font(ILSTheme.captionFont)
                                Slider(
                                    value: Binding(
                                        get: { Double(spacingXS) ?? 0 },
                                        set: { spacingXS = String(format: "%.0f", $0) }
                                    ),
                                    in: 0...100,
                                    step: 1
                                )
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Spacing S: \(spacingS.isEmpty ? "0" : spacingS) pt")
                                    .font(ILSTheme.captionFont)
                                Slider(
                                    value: Binding(
                                        get: { Double(spacingS) ?? 0 },
                                        set: { spacingS = String(format: "%.0f", $0) }
                                    ),
                                    in: 0...100,
                                    step: 1
                                )
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Spacing M: \(spacingM.isEmpty ? "0" : spacingM) pt")
                                    .font(ILSTheme.captionFont)
                                Slider(
                                    value: Binding(
                                        get: { Double(spacingM) ?? 0 },
                                        set: { spacingM = String(format: "%.0f", $0) }
                                    ),
                                    in: 0...100,
                                    step: 1
                                )
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Spacing L: \(spacingL.isEmpty ? "0" : spacingL) pt")
                                    .font(ILSTheme.captionFont)
                                Slider(
                                    value: Binding(
                                        get: { Double(spacingL) ?? 0 },
                                        set: { spacingL = String(format: "%.0f", $0) }
                                    ),
                                    in: 0...100,
                                    step: 1
                                )
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Spacing XL: \(spacingXL.isEmpty ? "0" : spacingXL) pt")
                                    .font(ILSTheme.captionFont)
                                Slider(
                                    value: Binding(
                                        get: { Double(spacingXL) ?? 0 },
                                        set: { spacingXL = String(format: "%.0f", $0) }
                                    ),
                                    in: 0...100,
                                    step: 1
                                )
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Spacing XXL: \(spacingXXL.isEmpty ? "0" : spacingXXL) pt")
                                    .font(ILSTheme.captionFont)
                                Slider(
                                    value: Binding(
                                        get: { Double(spacingXXL) ?? 0 },
                                        set: { spacingXXL = String(format: "%.0f", $0) }
                                    ),
                                    in: 0...100,
                                    step: 1
                                )
                            }
                        }

                        Group {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Button Padding Horizontal: \(buttonPaddingHorizontal.isEmpty ? "0" : buttonPaddingHorizontal) pt")
                                    .font(ILSTheme.captionFont)
                                Slider(
                                    value: Binding(
                                        get: { Double(buttonPaddingHorizontal) ?? 0 },
                                        set: { buttonPaddingHorizontal = String(format: "%.0f", $0) }
                                    ),
                                    in: 0...100,
                                    step: 1
                                )
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Button Padding Vertical: \(buttonPaddingVertical.isEmpty ? "0" : buttonPaddingVertical) pt")
                                    .font(ILSTheme.captionFont)
                                Slider(
                                    value: Binding(
                                        get: { Double(buttonPaddingVertical) ?? 0 },
                                        set: { buttonPaddingVertical = String(format: "%.0f", $0) }
                                    ),
                                    in: 0...100,
                                    step: 1
                                )
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Card Padding: \(cardPadding.isEmpty ? "0" : cardPadding) pt")
                                    .font(ILSTheme.captionFont)
                                Slider(
                                    value: Binding(
                                        get: { Double(cardPadding) ?? 0 },
                                        set: { cardPadding = String(format: "%.0f", $0) }
                                    ),
                                    in: 0...100,
                                    step: 1
                                )
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("List Item Spacing: \(listItemSpacing.isEmpty ? "0" : listItemSpacing) pt")
                                    .font(ILSTheme.captionFont)
                                Slider(
                                    value: Binding(
                                        get: { Double(listItemSpacing) ?? 0 },
                                        set: { listItemSpacing = String(format: "%.0f", $0) }
                                    ),
                                    in: 0...100,
                                    step: 1
                                )
                            }
                        }
                    } label: {
                        Label("Spacing Tokens (10)", systemImage: "arrow.left.and.right")
                    }
                } header: {
                    Text("Spacing")
                } footer: {
                    Text("Spacing values in points")
                }

                // MARK: - Corner Radius Tokens Section
                Section {
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedSections.contains("cornerRadius") },
                            set: { isExpanded in
                                if isExpanded {
                                    expandedSections.insert("cornerRadius")
                                } else {
                                    expandedSections.remove("cornerRadius")
                                }
                            }
                        )
                    ) {
                        Group {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Corner Radius S: \(cornerRadiusS.isEmpty ? "0" : cornerRadiusS) pt")
                                    .font(ILSTheme.captionFont)
                                Slider(
                                    value: Binding(
                                        get: { Double(cornerRadiusS) ?? 0 },
                                        set: { cornerRadiusS = String(format: "%.0f", $0) }
                                    ),
                                    in: 0...50,
                                    step: 1
                                )
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Corner Radius M: \(cornerRadiusM.isEmpty ? "0" : cornerRadiusM) pt")
                                    .font(ILSTheme.captionFont)
                                Slider(
                                    value: Binding(
                                        get: { Double(cornerRadiusM) ?? 0 },
                                        set: { cornerRadiusM = String(format: "%.0f", $0) }
                                    ),
                                    in: 0...50,
                                    step: 1
                                )
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Corner Radius L: \(cornerRadiusL.isEmpty ? "0" : cornerRadiusL) pt")
                                    .font(ILSTheme.captionFont)
                                Slider(
                                    value: Binding(
                                        get: { Double(cornerRadiusL) ?? 0 },
                                        set: { cornerRadiusL = String(format: "%.0f", $0) }
                                    ),
                                    in: 0...50,
                                    step: 1
                                )
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Corner Radius XL: \(cornerRadiusXL.isEmpty ? "0" : cornerRadiusXL) pt")
                                    .font(ILSTheme.captionFont)
                                Slider(
                                    value: Binding(
                                        get: { Double(cornerRadiusXL) ?? 0 },
                                        set: { cornerRadiusXL = String(format: "%.0f", $0) }
                                    ),
                                    in: 0...50,
                                    step: 1
                                )
                            }
                        }

                        Group {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Button Corner Radius: \(buttonCornerRadius.isEmpty ? "0" : buttonCornerRadius) pt")
                                    .font(ILSTheme.captionFont)
                                Slider(
                                    value: Binding(
                                        get: { Double(buttonCornerRadius) ?? 0 },
                                        set: { buttonCornerRadius = String(format: "%.0f", $0) }
                                    ),
                                    in: 0...50,
                                    step: 1
                                )
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Card Corner Radius: \(cardCornerRadius.isEmpty ? "0" : cardCornerRadius) pt")
                                    .font(ILSTheme.captionFont)
                                Slider(
                                    value: Binding(
                                        get: { Double(cardCornerRadius) ?? 0 },
                                        set: { cardCornerRadius = String(format: "%.0f", $0) }
                                    ),
                                    in: 0...50,
                                    step: 1
                                )
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Input Corner Radius: \(inputCornerRadius.isEmpty ? "0" : inputCornerRadius) pt")
                                    .font(ILSTheme.captionFont)
                                Slider(
                                    value: Binding(
                                        get: { Double(inputCornerRadius) ?? 0 },
                                        set: { inputCornerRadius = String(format: "%.0f", $0) }
                                    ),
                                    in: 0...50,
                                    step: 1
                                )
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Bubble Corner Radius: \(bubbleCornerRadius.isEmpty ? "0" : bubbleCornerRadius) pt")
                                    .font(ILSTheme.captionFont)
                                Slider(
                                    value: Binding(
                                        get: { Double(bubbleCornerRadius) ?? 0 },
                                        set: { bubbleCornerRadius = String(format: "%.0f", $0) }
                                    ),
                                    in: 0...50,
                                    step: 1
                                )
                            }
                        }
                    } label: {
                        Label("Corner Radius Tokens (8)", systemImage: "square.dashed")
                    }
                } header: {
                    Text("Corner Radius")
                } footer: {
                    Text("Corner radius values in points")
                }

                // MARK: - Shadow Tokens Section
                Section {
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedSections.contains("shadows") },
                            set: { isExpanded in
                                if isExpanded {
                                    expandedSections.insert("shadows")
                                } else {
                                    expandedSections.remove("shadows")
                                }
                            }
                        )
                    ) {
                        Group {
                            Text("Light Shadow")
                                .font(ILSTheme.captionFont)
                                .foregroundColor(ILSTheme.secondaryText)
                            ColorPicker("Color", selection: $shadowLightColor)
                            TextField("Opacity", text: $shadowLightOpacity)
                                .keyboardType(.decimalPad)
                            TextField("Radius", text: $shadowLightRadius)
                                .keyboardType(.decimalPad)
                            TextField("Offset X", text: $shadowLightOffsetX)
                                .keyboardType(.decimalPad)
                            TextField("Offset Y", text: $shadowLightOffsetY)
                                .keyboardType(.decimalPad)
                        }

                        Group {
                            Text("Medium Shadow")
                                .font(ILSTheme.captionFont)
                                .foregroundColor(ILSTheme.secondaryText)
                            ColorPicker("Color", selection: $shadowMediumColor)
                            TextField("Opacity", text: $shadowMediumOpacity)
                                .keyboardType(.decimalPad)
                            TextField("Radius", text: $shadowMediumRadius)
                                .keyboardType(.decimalPad)
                            TextField("Offset X", text: $shadowMediumOffsetX)
                                .keyboardType(.decimalPad)
                            TextField("Offset Y", text: $shadowMediumOffsetY)
                                .keyboardType(.decimalPad)
                        }

                        Group {
                            Text("Heavy Shadow")
                                .font(ILSTheme.captionFont)
                                .foregroundColor(ILSTheme.secondaryText)
                            ColorPicker("Color", selection: $shadowHeavyColor)
                            TextField("Opacity", text: $shadowHeavyOpacity)
                                .keyboardType(.decimalPad)
                            TextField("Radius", text: $shadowHeavyRadius)
                                .keyboardType(.decimalPad)
                            TextField("Offset X", text: $shadowHeavyOffsetX)
                                .keyboardType(.decimalPad)
                            TextField("Offset Y", text: $shadowHeavyOffsetY)
                                .keyboardType(.decimalPad)
                        }
                    } label: {
                        Label("Shadow Tokens (15)", systemImage: "shadow")
                    }
                } header: {
                    Text("Shadows")
                } footer: {
                    Text("Shadow properties: color (hex), opacity (0-1), radius and offsets (points)")
                }
            }
        }

    // MARK: - Save Theme

    private func saveTheme() async {
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
                shadows: shadows
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
                shadows: shadows
            )
        }

        isSaving = false

        if result != nil {
            dismiss()
        } else if let error = viewModel.error {
            saveErrorMessage = error.localizedDescription
            showSaveError = true
        }
    }

    // MARK: - Export Theme

    private func exportTheme() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let jsonData = try encoder.encode(previewTheme)

            // Create temporary file
            let fileName = "\(name.isEmpty ? "theme" : name.replacingOccurrences(of: " ", with: "_")).json"
            let tempDirectory = FileManager.default.temporaryDirectory
            let fileURL = tempDirectory.appendingPathComponent(fileName)

            // Write JSON to file
            try jsonData.write(to: fileURL)

            // Store URL for sharing
            exportURL = fileURL
            showShareSheet = true
        } catch {
            saveErrorMessage = "Failed to export theme: \(error.localizedDescription)"
            showSaveError = true
        }
    }

    // MARK: - Color Helpers

    private func colorFromHex(_ hex: String?) -> Color {
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

    private func hexFromColor(_ color: Color) -> String {
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

#Preview {
    ThemeEditorView()
        .environmentObject(ThemesViewModel())
}
