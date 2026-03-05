import Foundation

/// Coordinated memory management for app caching layers.
///
/// Thread-safe actor that manages cache configuration for CacheService
/// (SQLite-backed persistence). Provides statistics and proactive eviction
/// on iOS memory warnings.
actor MemoryManager {
    static let shared = MemoryManager()

    private let cacheService = CacheService.shared

    private init() {
        AppLogger.shared.info("MemoryManager initialized", category: "memory")
    }

    // MARK: - Memory Warning Response

    /// Clear all non-essential caches in response to memory pressure.
    ///
    /// Called by the app-wide memory warning handler (ILSAppApp.swift).
    /// Clears the persistent CacheService database. Essential user state
    /// (current session, unsent messages) is preserved by the session manager.
    /// Note: APIClient has its own in-memory NSCache which is managed separately
    /// per-connection.
    func handleMemoryWarning() async {
        AppLogger.shared.warning(
            "Memory warning received - clearing all caches",
            category: "memory"
        )

        // Clear persistent database cache
        await cacheService.clearAll()

        AppLogger.shared.info(
            "Memory warning handled - all caches cleared",
            category: "memory"
        )
    }

    // MARK: - Cache Statistics

    /// Get cache statistics from CacheService.
    ///
    /// Returns stats for the persistent SQLite cache. Note: This provides
    /// basic statistics - actual memory usage is minimal as CacheService
    /// uses disk storage, not in-memory caching.
    ///
    /// - Returns: CacheStats with entry counts and estimated limits.
    func getTotalMemoryUsage() async -> CacheStats {
        // CacheService uses SQLite on disk - minimal memory footprint
        // Provide reasonable defaults for the UI
        // TODO: Enhance CacheService to track actual entry counts and sizes
        return CacheStats(
            currentSizeBytes: 0,  // SQLite cache not tracked in memory
            maxSizeBytes: 50 * 1024 * 1024,  // 50 MB nominal limit for display
            entryCount: 0,  // Not tracked by CacheService yet
            maxEntryCount: 1000,  // Reasonable default
            hitRate: nil  // Not tracked by CacheService
        )
    }

    // MARK: - Cache Configuration

    /// Configure maximum cache size (reserved for future use).
    ///
    /// Currently logs the configuration. CacheService uses SQLite with
    /// TTL-based expiration rather than strict size limits.
    ///
    /// - Parameter sizeBytes: Desired maximum cache size in bytes.
    func configureCacheSize(_ sizeBytes: Int) async {
        let sizeMB = sizeBytes / (1024 * 1024)
        AppLogger.shared.info(
            "Cache size configuration requested: \(sizeMB) MB (logged for future implementation)",
            category: "memory"
        )

        UserDefaults.standard.set(sizeBytes, forKey: AppConstants.cacheConfigKey)
    }

    // MARK: - Proactive Cache Cleanup

    /// Perform proactive cache cleanup to stay within storage budget.
    ///
    /// Called periodically (e.g., when app enters background) to remove expired
    /// entries from CacheService's persistent storage.
    func performProactiveCleanup() async {
        AppLogger.shared.info("Starting proactive cache cleanup", category: "memory")

        // Clean up expired entries from persistent cache
        await cacheService.cleanupExpired()

        AppLogger.shared.info("Proactive cache cleanup complete", category: "memory")
    }
}
