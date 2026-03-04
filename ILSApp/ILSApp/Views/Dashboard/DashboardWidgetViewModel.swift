import Foundation
import Observation

// MARK: - DashboardWidgetViewModel

/// Protocol all dashboard widget view-models must conform to.
///
/// Conforming types are expected to use the `@Observable` macro so that SwiftUI
/// automatically invalidates the containing ``WidgetContainerView`` when
/// `isLoading` or `isOffline` changes. Because the protocol requires `Observable`,
/// it can only be satisfied by `@Observable` classes — this keeps observation
/// tracking zero-cost at compile time rather than relying on existential
/// `any Observable` at runtime.
///
/// ## Usage
/// ```swift
/// @Observable
/// @MainActor
/// final class ActiveSessionsWidgetViewModel: DashboardWidgetViewModel {
///     var isLoading = false
///     var isOffline = false
///
///     func loadContent() async { ... }
/// }
/// ```
///
/// ## Topics
/// ### Properties
/// - ``isLoading`` - True while fetching initial or refreshed data
/// - ``isOffline`` - True when the backend is unreachable
///
/// ### Actions
/// - ``loadContent()`` - Fetches or refreshes the widget's data
@MainActor
protocol DashboardWidgetViewModel: AnyObject, Observable {
    /// True while the widget is fetching its initial or refreshed data.
    /// Setting this to `true` triggers the shimmer loading overlay in
    /// ``WidgetContainerView``.
    var isLoading: Bool { get }

    /// True when the app has no network connectivity or the backend is
    /// unreachable. Setting this to `true` replaces the widget content with
    /// the offline empty state in ``WidgetContainerView``.
    var isOffline: Bool { get }

    /// Fetches or refreshes the widget's data from the backend.
    ///
    /// Called automatically when the widget appears on screen and whenever
    /// the dashboard pulls to refresh. Implementations should set `isLoading`
    /// and `isOffline` appropriately during and after the fetch.
    func loadContent() async
}
