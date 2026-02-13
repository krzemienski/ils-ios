// PlatformCompat.swift
// Cross-platform compatibility shims for iOS-only SwiftUI modifiers.
// On macOS these are no-ops so shared view code compiles unchanged.

import SwiftUI

#if os(macOS)

// MARK: - Keyboard Type

enum UIKeyboardType: Int {
    case `default` = 0
    case asciiCapable = 1
    case numbersAndPunctuation = 2
    case URL = 3
    case numberPad = 4
    case phonePad = 5
    case namePhonePad = 6
    case emailAddress = 7
    case decimalPad = 8
    case twitter = 9
    case webSearch = 10
    case asciiCapableNumberPad = 11
}

extension View {
    func keyboardType(_ type: UIKeyboardType) -> some View {
        self
    }
}

// MARK: - Autocapitalization (legacy)

enum UITextAutocapitalizationType: Int {
    case none = 0
    case words = 2
    case sentences = 1
    case allCharacters = 3
}

extension View {
    func autocapitalization(_ style: UITextAutocapitalizationType) -> some View {
        self
    }
}

// MARK: - Text Input Autocapitalization (modern)

enum TextInputAutocapitalization {
    case never
    case words
    case sentences
    case characters
}

extension View {
    func textInputAutocapitalization(_ autocapitalization: TextInputAutocapitalization?) -> some View {
        self
    }
}

// MARK: - Navigation Bar Title Display Mode

enum NavigationBarTitleDisplayMode {
    case automatic
    case inline
    case large
}

extension View {
    func navigationBarTitleDisplayMode(_ displayMode: NavigationBarTitleDisplayMode) -> some View {
        self
    }
}

// MARK: - Toolbar Item Placement Extensions

extension ToolbarItemPlacement {
    static var navigationBarTrailing: ToolbarItemPlacement { .automatic }
    static var navigationBarLeading: ToolbarItemPlacement { .automatic }
}

#endif
