// AdaptiveLayout.swift
// Reusable utilities for responsive, width-adaptive layouts.
// Provides environment-based breakpoints so views react to window width
// changes automatically — essential for iPad multitasking (Split View,
// Slide Over) and varying device sizes.

import SwiftUI

// MARK: - Layout Size Class

/// Describes the available horizontal space for layout decisions.
///
/// Use this instead of raw point values so every view agrees on the
/// same breakpoints.
///
/// | Case     | Width        | Typical Scenario                    |
/// |----------|-------------|-------------------------------------|
/// | narrow   | < 500 pt    | 1/3 Split View, Slide Over, iPhone  |
/// | regular  | 500–900 pt  | 1/2 Split View                      |
/// | wide     | > 900 pt    | 2/3+ Split View, full-screen iPad   |
enum LayoutSizeClass: String, Sendable {
    case narrow
    case regular
    case wide

    /// Determine the layout size class for a given width.
    ///
    /// - Parameter width: The available horizontal space in points.
    /// - Returns: The corresponding `LayoutSizeClass`.
    static func from(width: CGFloat) -> LayoutSizeClass {
        if width < 500 {
            return .narrow
        } else if width <= 900 {
            return .regular
        } else {
            return .wide
        }
    }
}

// MARK: - Environment Keys

/// Environment key that carries the current window width in points.
private struct WindowWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = 393 // iPhone 15 Pro logical width
}

/// Environment key that carries the computed layout size class.
private struct LayoutSizeClassKey: EnvironmentKey {
    static let defaultValue: LayoutSizeClass = .narrow
}

extension EnvironmentValues {
    /// The current window/container width in points.
    var windowWidth: CGFloat {
        get { self[WindowWidthKey.self] }
        set { self[WindowWidthKey.self] = newValue }
    }

    /// The computed layout size class based on ``windowWidth``.
    var layoutSizeClass: LayoutSizeClass {
        get { self[LayoutSizeClassKey.self] }
        set { self[LayoutSizeClassKey.self] = newValue }
    }
}

// MARK: - Adaptive Layout Modifier

/// A `ViewModifier` that measures the available width via `GeometryReader`
/// and injects both ``windowWidth`` and ``layoutSizeClass`` into the
/// environment for all descendant views.
///
/// Apply once near the root of a navigation stack or scene; child views
/// read the environment values directly.
///
/// ```swift
/// NavigationStack {
///     MyContentView()
/// }
/// .adaptiveLayout()
/// ```
struct AdaptiveLayoutModifier: ViewModifier {
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let sizeClass = LayoutSizeClass.from(width: width)

            content
                .environment(\.windowWidth, width)
                .environment(\.layoutSizeClass, sizeClass)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Wraps this view in a `GeometryReader` that publishes adaptive layout
    /// environment values (``windowWidth`` and ``layoutSizeClass``).
    ///
    /// Attach this modifier near the root of your view hierarchy so that
    /// all descendants can read the current layout size class:
    ///
    /// ```swift
    /// @Environment(\.layoutSizeClass) private var layoutSizeClass
    /// ```
    func adaptiveLayout() -> some View {
        modifier(AdaptiveLayoutModifier())
    }

    /// Returns an appropriate number of grid columns for the current width.
    ///
    /// Uses the environment's ``layoutSizeClass`` to decide:
    /// - **narrow**: `base` columns (default 1)
    /// - **regular**: `base * 2` columns
    /// - **wide**: `base * 3` columns
    ///
    /// - Parameter base: The minimum number of columns for narrow layouts.
    /// - Returns: A view that reads the environment and provides the column count.
    func adaptiveColumns(base: Int = 1, content: @escaping (Int) -> some View) -> some View {
        AdaptiveColumnsView(base: base, content: content)
    }
}

// MARK: - Adaptive Columns Helper

/// Internal view that reads the layout size class from the environment
/// and provides the computed column count to a builder closure.
private struct AdaptiveColumnsView<Content: View>: View {
    let base: Int
    let content: (Int) -> Content

    @Environment(\.layoutSizeClass) private var layoutSizeClass

    var body: some View {
        content(columnCount)
    }

    private var columnCount: Int {
        switch layoutSizeClass {
        case .narrow:
            return base
        case .regular:
            return base * 2
        case .wide:
            return base * 3
        }
    }
}

// MARK: - Adaptive Grid Columns

/// Convenience for building `GridItem` arrays that adapt to the layout.
enum AdaptiveGridLayout {
    /// Creates a flexible grid column array sized for the given layout.
    ///
    /// - Parameters:
    ///   - sizeClass: The current layout size class.
    ///   - minimum: Minimum column width in points. Defaults to 160.
    /// - Returns: An array of `GridItem` values for use with `LazyVGrid`.
    static func columns(
        for sizeClass: LayoutSizeClass,
        minimum: CGFloat = 160
    ) -> [GridItem] {
        let count: Int
        switch sizeClass {
        case .narrow:
            count = 1
        case .regular:
            count = 2
        case .wide:
            count = 3
        }
        return Array(repeating: GridItem(.adaptive(minimum: minimum), spacing: 12), count: count)
    }
}
