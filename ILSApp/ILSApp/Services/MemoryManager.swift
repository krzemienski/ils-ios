import Foundation

/// Coordinated memory management for app caching layers.
///
/// Thread-safe actor that manages cache configuration for both APIClient's
/// in-memory NSCache (primary memory consumer) and CacheService SQLite-backed
/// persistence. Provides statistics and proactive eviction on iOS memory warnings.
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
    /// Clears both the in-memory APIClient NSCache (primary memory consumer)
    /// and the persistent CacheService database. Essential user state
    /// (current session, unsent messages) is preserved by the session manager.
    ///
    /// - Parameter connectionManager: Active ConnectionManager instance providing
    ///   access to the current APIClient for cache eviction.
    func handleMemoryWarning(connectionManager: ConnectionManager) async {
        AppLogger.shared.warning(
            "Memory warning received - clearing all caches",
            category: "memory"
        )

        // Clear in-memory HTTP response cache (APIClient NSCache - primary memory consumer)
        await connectionManager.apiClient.clearCache()

        // Clear persistent database cache (CacheService SQLite - minimal memory impact)
        await cacheService.clearAll()

        AppLogger.shared.info(
            "Memory warning handled - all caches cleared",
            category: "memory"
        )
    }

    // MARK: - Cache Statistics

    /// Get cache statistics from APIClient.
    ///
    /// Returns stats for the in-memory NSCache which is the primary memory consumer.
    /// CacheService uses SQLite on disk with minimal memory footprint.
    ///
    /// - Parameter connectionManager: Active ConnectionManager instance providing
    ///   access to the current APIClient for statistics.
    /// - Returns: CacheStats with actual cache size, entry counts, and hit rate.
    func getTotalMemoryUsage(from connectionManager: ConnectionManager) async -> CacheStats {
        // Get real statistics from the active APIClient instance
        await connectionManager.apiClient.getCacheStats()
    }

    // MARK: - Cache Configuration

    /// Configure maximum cache size and apply to active APIClient.
    ///
    /// Persists the configuration to UserDefaults and applies it to the
    /// current APIClient's NSCache and conditional cache limits. New
    /// connections will read this value from UserDefaults on initialization.
    ///
    /// - Parameters:
    ///   - sizeBytes: Desired maximum cache size in bytes.
    ///   - connectionManager: Active ConnectionManager instance for applying
    ///     the limit to the current APIClient.
    func configureCacheSize(_ sizeBytes: Int, connectionManager: ConnectionManager) async {
        let sizeMB = sizeBytes / (1024 * 1024)
        AppLogger.shared.info(
            "Configuring cache size to \(sizeMB) MB",
            category: "memory"
        )

        // Persist configuration
        UserDefaults.standard.set(sizeBytes, forKey: AppConstants.cacheConfigKey)

        // Apply to active APIClient NSCache
        await connectionManager.apiClient.updateCacheLimit(sizeBytes)
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
