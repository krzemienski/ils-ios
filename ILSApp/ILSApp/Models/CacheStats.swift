import Foundation

// MARK: - Cache Statistics

/// Statistics for monitoring cache usage and performance.
///
/// Provides real-time metrics about cache size, entry counts, and hit rates
/// for memory management and debugging. Used by MemoryManager and Settings UI
/// to display cache health and enable informed eviction decisions.
struct CacheStats: Codable, Sendable {
    /// Current cache size in bytes.
    let currentSizeBytes: Int

    /// Maximum allowed cache size in bytes.
    let maxSizeBytes: Int

    /// Current number of cached entries.
    let entryCount: Int

    /// Maximum allowed number of entries.
    let maxEntryCount: Int

    /// Cache hit rate as a percentage (0.0 to 1.0), if available.
    ///
    /// Calculated as hits / (hits + misses). `nil` if tracking is not enabled
    /// or insufficient data is available.
    let hitRate: Double?

    /// Convenience computed property for cache utilization as a percentage.
    var utilizationPercent: Double {
        guard maxSizeBytes > 0 else { return 0 }
        return Double(currentSizeBytes) / Double(maxSizeBytes) * 100.0
    }

    /// Whether the cache is near its size limit (>80% utilization).
    var isNearLimit: Bool {
        utilizationPercent > 80.0
    }

    /// Human-readable cache size string (e.g., "12.5 MB").
    var currentSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(currentSizeBytes), countStyle: .memory)
    }

    /// Human-readable maximum size string (e.g., "50 MB").
    var maxSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(maxSizeBytes), countStyle: .memory)
    }
}
