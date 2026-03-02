import Foundation
import SwiftUI

/// Parses ANSI SGR (Select Graphic Rendition) escape sequences and converts
/// terminal output into an AttributedString suitable for SwiftUI rendering.
///
/// Supported sequences:
/// - `ESC[0m`        Reset all attributes
/// - `ESC[1m`        Bold
/// - `ESC[3m`        Italic
/// - `ESC[4m`        Underline
/// - `ESC[22m`       Bold off
/// - `ESC[23m`       Italic off
/// - `ESC[24m`       Underline off
/// - `ESC[30m–37m`   Standard foreground colors (0–7)
/// - `ESC[39m`       Default foreground color
/// - `ESC[38;5;nm`   256-color foreground
/// - `ESC[90m–97m`   Bright foreground colors (8–15)
enum ANSIParser {

    // MARK: - State

    /// Active rendering state derived from parsed SGR codes
    private struct State {
        var foregroundColor: Color?
        var isBold: Bool = false
        var isItalic: Bool = false
        var isUnderline: Bool = false

        mutating func reset() {
            foregroundColor = nil
            isBold = false
            isItalic = false
            isUnderline = false
        }
    }

    // MARK: - Regex

    /// Matches SGR escape sequences: ESC[ <params> m
    private static let sgrRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: "\u{001B}\\[([0-9;]*)m", options: [])
    }()

    // MARK: - Public API

    /// Convert a raw terminal string containing ANSI escape sequences to an
    /// `AttributedString` with colors, bold, italic, and underline applied.
    /// - Parameter text: Raw terminal output (may contain ANSI codes)
    /// - Returns: `AttributedString` with styles applied; plain monospaced on
    ///   parse failure
    static func parse(_ text: String) -> AttributedString {
        guard let regex = sgrRegex else {
            return makePlain(text)
        }

        var result = AttributedString()
        var state = State()
        var cursor = text.startIndex

        let nsText = text as NSString
        let matches = regex.matches(
            in: text,
            options: [],
            range: NSRange(location: 0, length: nsText.length)
        )

        // Pre-allocate: each match yields at most one text segment + one escape
        result.characters.reserveCapacity(text.count)

        for match in matches {
            let matchRange = match.range
            let matchStart = text.index(text.startIndex, offsetBy: matchRange.location)

            // Append styled text before this escape sequence
            if cursor < matchStart {
                result.append(styled(String(text[cursor..<matchStart]), state: state))
            }

            // Parse SGR parameters from capture group 1
            let paramsRange = match.range(at: 1)
            if paramsRange.location != NSNotFound {
                applyParams(nsText.substring(with: paramsRange), to: &state)
            }

            cursor = text.index(
                text.startIndex,
                offsetBy: matchRange.location + matchRange.length
            )
        }

        // Append any remaining text after the last escape sequence
        if cursor < text.endIndex {
            result.append(styled(String(text[cursor..<text.endIndex]), state: state))
        }

        return result
    }

    // MARK: - SGR Parameter Handling

    /// Apply semicolon-separated SGR codes to the current rendering state.
    private static func applyParams(_ params: String, to state: inout State) {
        // Empty params (ESC[m) is equivalent to ESC[0m — full reset
        if params.isEmpty {
            state.reset()
            return
        }

        let codes = params.split(separator: ";").compactMap { Int($0) }
        var index = 0

        while index < codes.count {
            let code = codes[index]

            switch code {
            case 0:
                state.reset()
            case 1:
                state.isBold = true
            case 3:
                state.isItalic = true
            case 4:
                state.isUnderline = true
            case 22:
                state.isBold = false
            case 23:
                state.isItalic = false
            case 24:
                state.isUnderline = false
            case 30...37:
                state.foregroundColor = standardColor(code - 30)
            case 38:
                // 256-color mode: 38;5;n
                if index + 2 < codes.count, codes[index + 1] == 5 {
                    state.foregroundColor = color256(codes[index + 2])
                    index += 2
                }
            case 39:
                state.foregroundColor = nil
            case 90...97:
                // Bright variants map to palette indices 8–15
                state.foregroundColor = standardColor(code - 90 + 8)
            default:
                break
            }

            index += 1
        }
    }

    // MARK: - AttributedString Helpers

    /// Create an `AttributedString` segment with the current state applied.
    private static func styled(_ text: String, state: State) -> AttributedString {
        var segment = AttributedString(text)

        var font = Font.system(.body, design: .monospaced)
        if state.isBold   { font = font.bold() }
        if state.isItalic { font = font.italic() }
        segment.font = font

        if let color = state.foregroundColor {
            segment.foregroundColor = color
        }

        if state.isUnderline {
            segment.underlineStyle = Text.LineStyle(pattern: .solid)
        }

        return segment
    }

    /// Plain monospaced `AttributedString` — used as fallback when regex is unavailable.
    private static func makePlain(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        result.font = .system(.body, design: .monospaced)
        return result
    }

    // MARK: - Color Palettes

    /// Standard 16-color palette (indices 0–15).
    /// 0–7: normal; 8–15: bright variants.
    private static func standardColor(_ index: Int) -> Color {
        switch index {
        case 0:  return Color(red: 0.00, green: 0.00, blue: 0.00) // Black
        case 1:  return Color(red: 0.80, green: 0.00, blue: 0.00) // Red
        case 2:  return Color(red: 0.00, green: 0.80, blue: 0.00) // Green
        case 3:  return Color(red: 0.80, green: 0.80, blue: 0.00) // Yellow
        case 4:  return Color(red: 0.00, green: 0.00, blue: 0.80) // Blue
        case 5:  return Color(red: 0.80, green: 0.00, blue: 0.80) // Magenta
        case 6:  return Color(red: 0.00, green: 0.80, blue: 0.80) // Cyan
        case 7:  return Color(red: 0.80, green: 0.80, blue: 0.80) // White
        case 8:  return Color(red: 0.40, green: 0.40, blue: 0.40) // Bright Black (dark gray)
        case 9:  return Color(red: 1.00, green: 0.30, blue: 0.30) // Bright Red
        case 10: return Color(red: 0.30, green: 1.00, blue: 0.30) // Bright Green
        case 11: return Color(red: 1.00, green: 1.00, blue: 0.30) // Bright Yellow
        case 12: return Color(red: 0.30, green: 0.30, blue: 1.00) // Bright Blue
        case 13: return Color(red: 1.00, green: 0.30, blue: 1.00) // Bright Magenta
        case 14: return Color(red: 0.30, green: 1.00, blue: 1.00) // Bright Cyan
        case 15: return Color(red: 1.00, green: 1.00, blue: 1.00) // Bright White
        default: return Color.primary
        }
    }

    /// Convert a 256-color palette index to a `Color`.
    ///
    /// - Indices 0–15:   Standard 16 colors (delegates to `standardColor`)
    /// - Indices 16–231: 6×6×6 RGB color cube
    /// - Indices 232–255: Grayscale ramp
    private static func color256(_ index: Int) -> Color {
        switch index {
        case 0...15:
            return standardColor(index)

        case 16...231:
            let n = index - 16
            let b = n % 6
            let g = (n / 6) % 6
            let r = n / 36
            // Each cube step: 0 → 0, 1–5 → (40×step + 55) / 255
            let toFloat: (Int) -> Double = { v in
                v == 0 ? 0.0 : (Double(v) * 40.0 + 55.0) / 255.0
            }
            return Color(red: toFloat(r), green: toFloat(g), blue: toFloat(b))

        case 232...255:
            let level = index - 232
            let value = Double(level * 10 + 8) / 255.0
            return Color(red: value, green: value, blue: value)

        default:
            return Color.primary
        }
    }
}
