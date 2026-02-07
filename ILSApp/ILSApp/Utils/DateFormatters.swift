import Foundation

/// Centralized date formatters to avoid repeated allocation.
/// DateFormatter is expensive to create — these are shared static instances.
enum DateFormatters {
    /// Relative date/time (e.g., "2 hours ago")
    static let relativeDateTime: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    /// Time only (e.g., "2:30 PM")
    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    /// Full date and time (e.g., "Feb 7, 2026 at 2:30 PM")
    static let dateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    /// Date only (e.g., "Feb 7, 2026")
    static let date: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
