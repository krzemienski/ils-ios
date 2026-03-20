import Vapor
import ILSShared

/// Storage key for shared AbuseDetectionService instance.
struct AbuseDetectionServiceKey: StorageKey {
    typealias Value = AbuseDetectionService
}

/// Tracks rate limit violations, repeated auth failures, and suspicious request patterns per IP.
///
/// Maintains an in-memory ring buffer of recent `SecurityAuditEvent` records, logs abuse events
/// at warning level, and provides an admin-only endpoint to retrieve the abuse log.
///
/// ## Usage
/// Register at app startup via `app.storage[AbuseDetectionServiceKey.self]`.
/// Middleware can then report violations via `recordRateLimitViolation(...)` or
/// `recordAuthFailure(...)`.
actor AbuseDetectionService {
    /// Maximum number of audit events retained in the ring buffer.
    private let maxEvents: Int

    /// Ring buffer of recent abuse events (newest last).
    private var events: [SecurityAuditEvent] = []

    /// Tracks per-IP violation counts for pattern detection.
    /// Key: IP address, Value: (rateLimitViolations, authFailures, lastSeen)
    private var ipViolationCounts: [String: IPViolationRecord] = [:]

    /// Periodic cleanup timestamp.
    private var lastCleanup: Date = Date()

    /// Cleanup interval for stale IP records.
    private let cleanupInterval: TimeInterval = 600 // 10 minutes

    /// Threshold for escalating severity to critical.
    private let criticalThreshold: Int = 20

    /// Threshold for escalating severity to error.
    private let errorThreshold: Int = 10

    struct IPViolationRecord {
        var rateLimitViolations: Int = 0
        var authFailures: Int = 0
        var suspiciousRequests: Int = 0
        var lastSeen: Date = Date()
    }

    init(maxEvents: Int = 1000) {
        self.maxEvents = maxEvents
    }

    // MARK: - Recording Events

    /// Record a rate limit violation from an IP address.
    ///
    /// - Parameters:
    ///   - ip: Source IP address.
    ///   - path: The endpoint path that was rate-limited.
    ///   - group: The rate limit group that was exceeded.
    ///   - logger: Logger for emitting warnings.
    func recordRateLimitViolation(
        ip: String,
        path: String,
        group: String,
        logger: Logger
    ) {
        let record = updateViolationCount(ip: ip, type: .rateLimit)
        let totalViolations = record.rateLimitViolations
        let severity = resolveSeverity(totalViolations: totalViolations)

        let event = SecurityAuditEvent(
            id: generateEventID(),
            category: .rateLimitViolation,
            severity: severity,
            message: "Rate limit exceeded for \(ip) on \(path) [group=\(group), count=\(totalViolations)]",
            endpoint: path,
            sourceIP: ip,
            metadata: [
                "group": group,
                "violation_count": String(totalViolations)
            ]
        )

        appendEvent(event)
        logger.warning("ABUSE: \(event.message)")
    }

    /// Record an authentication failure from an IP address.
    ///
    /// - Parameters:
    ///   - ip: Source IP address.
    ///   - path: The endpoint path where auth failed.
    ///   - reason: The reason for the auth failure.
    ///   - logger: Logger for emitting warnings.
    func recordAuthFailure(
        ip: String,
        path: String,
        reason: String,
        logger: Logger
    ) {
        let record = updateViolationCount(ip: ip, type: .authFailure)
        let totalFailures = record.authFailures
        let severity = resolveSeverity(totalViolations: totalFailures)

        let event = SecurityAuditEvent(
            id: generateEventID(),
            category: .authFailure,
            severity: severity,
            message: "Auth failure from \(ip) on \(path): \(reason) [count=\(totalFailures)]",
            endpoint: path,
            sourceIP: ip,
            metadata: [
                "reason": reason,
                "failure_count": String(totalFailures)
            ]
        )

        appendEvent(event)
        logger.warning("ABUSE: \(event.message)")
    }

    /// Record a suspicious request pattern from an IP address.
    ///
    /// - Parameters:
    ///   - ip: Source IP address.
    ///   - path: The endpoint path.
    ///   - reason: Description of the suspicious pattern.
    ///   - logger: Logger for emitting warnings.
    func recordSuspiciousRequest(
        ip: String,
        path: String,
        reason: String,
        logger: Logger
    ) {
        let record = updateViolationCount(ip: ip, type: .suspicious)
        let totalSuspicious = record.suspiciousRequests
        let severity = resolveSeverity(totalViolations: totalSuspicious)

        let event = SecurityAuditEvent(
            id: generateEventID(),
            category: .suspiciousActivity,
            severity: severity,
            message: "Suspicious request from \(ip) on \(path): \(reason) [count=\(totalSuspicious)]",
            endpoint: path,
            sourceIP: ip,
            metadata: [
                "reason": reason,
                "suspicious_count": String(totalSuspicious)
            ]
        )

        appendEvent(event)
        logger.warning("ABUSE: \(event.message)")
    }

    // MARK: - Querying Events

    /// Retrieve recent abuse events, newest first.
    ///
    /// - Parameters:
    ///   - limit: Maximum number of events to return (default 100).
    ///   - category: Optional category filter.
    /// - Returns: A `SecurityAuditEventsResponse` with the matching events.
    func recentEvents(
        limit: Int = 100,
        category: SecurityAuditCategory? = nil
    ) -> SecurityAuditEventsResponse {
        var filtered = events
        if let category = category {
            filtered = filtered.filter { $0.category == category }
        }

        let total = filtered.count
        let items = Array(filtered.suffix(limit).reversed())
        let hasMore = total > limit

        return SecurityAuditEventsResponse(
            items: items,
            total: total,
            hasMore: hasMore
        )
    }

    // MARK: - Private Helpers

    private enum ViolationType {
        case rateLimit
        case authFailure
        case suspicious
    }

    /// Update violation count for an IP and return the updated record.
    @discardableResult
    private func updateViolationCount(ip: String, type: ViolationType) -> IPViolationRecord {
        let now = Date()

        // Periodic cleanup of stale IP records
        if now.timeIntervalSince(lastCleanup) > cleanupInterval {
            cleanupStaleRecords(before: now.addingTimeInterval(-3600)) // 1 hour
            lastCleanup = now
        }

        var record = ipViolationCounts[ip] ?? IPViolationRecord()
        record.lastSeen = now

        switch type {
        case .rateLimit:
            record.rateLimitViolations += 1
        case .authFailure:
            record.authFailures += 1
        case .suspicious:
            record.suspiciousRequests += 1
        }

        ipViolationCounts[ip] = record
        return record
    }

    /// Resolve severity based on the total violation count.
    private func resolveSeverity(totalViolations: Int) -> SecurityAuditSeverity {
        if totalViolations >= criticalThreshold {
            return .critical
        } else if totalViolations >= errorThreshold {
            return .error
        } else {
            return .warning
        }
    }

    /// Append an event to the ring buffer, evicting the oldest if at capacity.
    private func appendEvent(_ event: SecurityAuditEvent) {
        events.append(event)
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
    }

    /// Remove IP violation records that haven't been seen recently.
    private func cleanupStaleRecords(before cutoff: Date) {
        var keysToRemove: [String] = []
        for (ip, record) in ipViolationCounts {
            if record.lastSeen < cutoff {
                keysToRemove.append(ip)
            }
        }
        for key in keysToRemove {
            ipViolationCounts.removeValue(forKey: key)
        }
    }

    /// Generate a unique event ID.
    private func generateEventID() -> String {
        UUID().uuidString.lowercased()
    }
}
