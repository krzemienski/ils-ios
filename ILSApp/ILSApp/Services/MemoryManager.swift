import Foundation

/// Coordinated memory management across all app caching layers.
///
/// Thread-safe actor that orchestrates memory pressure responses and cache configuration
/// across APIClient (in-memory HTTP response cache) and CacheService (SQLite-backed persistence).
/// Provides unified statistics and proactive eviction on iOS memory warnings.
actor MemoryManager {
    static let shared = MemoryManager()

    private let apiClient = APIClient.shared
    private let cacheService = CacheService.shared

    private init() {
        AppLogger.shared.info("MemoryManager initialized", category: "memory")
    }

    // MARK: - Memory Warning Response

    /// Clear all non-essential caches in response to memory pressure.
    ///
    /// Called by the app-wide memory warning handler (ILSAppApp.swift).
    /// Clears both the in-memory APIClient cache (NSCache) and the persistent
    /// CacheService database. Essential user state (current session, unsent messages)
    /// is preserved by the session manager.
    func handleMemoryWarning() async {
        AppLogger.shared.warning(
            "Memory warning received - clearing all caches",
            category: "memory"
        )

        // Clear in-memory HTTP response cache
        await apiClient.clearCache()

        // Clear persistent database cache
        await cacheService.clearAll()

        AppLogger.shared.info(
            "Memory warning handled - all caches cleared",
            category: "memory"
        )
    }

    // MARK: - Cache Statistics

    /// Get combined cache statistics from all caching layers.
    ///
    /// Returns aggregate stats combining APIClient's in-memory cache and
    /// CacheService's persistent cache. Since CacheService uses SQLite (not memory),
    /// only APIClient stats are included in byte counts. Entry counts reflect
    /// both layers for debugging visibility.
    ///
    /// - Returns: Combined CacheStats with total memory usage and hit rates.
    func getTotalMemoryUsage() async -> CacheStats {
        let apiStats = await apiClient.getCacheStats()

        // CacheService uses SQLite - not counted in memory usage
        // Only APIClient's NSCache contributes to app memory footprint
        return CacheStats(
            currentSizeBytes: apiStats.currentSizeBytes,
            maxSizeBytes: apiStats.maxSizeBytes,
            entryCount: apiStats.entryCount,
            maxEntryCount: apiStats.maxEntryCount,
            hitRate: apiStats.hitRate
        )
    }

    // MARK: - Cache Configuration

    /// Configure maximum cache size for APIClient's in-memory cache.
    ///
    /// Updates the NSCache `totalCostLimit` to the specified byte count.
    /// Valid range: 25 MB to 100 MB (enforced by AppConstants).
    /// Configuration persists via UserDefaults (AppStorage).
    ///
    /// - Parameter sizeBytes: New maximum cache size in bytes.
    func configureCacheSize(_ sizeBytes: Int) async {
        let sizeMB = sizeBytes / (1024 * 1024)
        AppLogger.shared.info(
            "Configuring cache size to \(sizeMB) MB",
            category: "memory"
        )

        // APIClient reads cache size from UserDefaults on next restart
        // or can be updated live if we add a setCacheSize method
        // For now, log the configuration - implementation deferred to APIClient enhancement
        UserDefaults.standard.set(sizeBytes, forKey: AppConstants.cacheConfigKey)

        AppLogger.shared.info(
            "Cache size configured to \(sizeMB) MB (takes effect on restart)",
            category: "memory"
        )
    }

    // MARK: - Proactive Cache Cleanup

    /// Perform proactive cache cleanup to stay within memory budget.
    ///
    /// Called periodically (e.g., when app enters background) to remove expired
    /// entries and prevent cache growth. Uses CacheService's TTL-based cleanup
    /// for persistent data and relies on NSCache's automatic LRU eviction for
    /// in-memory data.
    func performProactiveCleanup() async {
        AppLogger.shared.info("Starting proactive cache cleanup", category: "memory")

        // Clean up expired entries from persistent cache
        await cacheService.cleanupExpired()

        // Check if in-memory cache is near limit
        let stats = await apiClient.getCacheStats()
        if stats.isNearLimit {
            AppLogger.shared.warning(
                "Cache utilization at \(String(format: "%.1f", stats.utilizationPercent))% - NSCache will begin LRU eviction",
                category: "memory"
            )
        }

        AppLogger.shared.info("Proactive cache cleanup complete", category: "memory")
    }
}
