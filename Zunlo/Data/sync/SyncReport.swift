//
//  SyncReport.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/26/25.
//

public struct PushStats: Sendable {
    public var inserted: Int = 0
    public var updated: Int = 0
    public var conflicts: Int = 0
    // Optional extras if you want them later:
    public var missing: Int = 0          // 404s on update
    public var transientFailures: Int = 0
    public var rateLimited: Int = 0

    public static let zero = PushStats()
}

public struct PullStats: Sendable {
    public var pulled: Int = 0
    // Optional extras:
    public var pages: Int = 0
    public var tombstones: Int = 0

    public static let zero = PullStats()
}

/// Final merged report you can log/return from `syncNow()`
public struct SyncReport: Sendable, CustomStringConvertible {
    public var inserted: Int
    public var updated: Int
    public var conflicts: Int
    public var pulled: Int

    public var pushed: Int { inserted + updated }

    public static let zero = SyncReport(inserted: 0, updated: 0, conflicts: 0, pulled: 0)

    public static func from(push: PushStats, pull: PullStats) -> SyncReport {
        SyncReport(
            inserted: push.inserted,
            updated: push.updated,
            conflicts: push.conflicts,
            pulled: pull.pulled
        )
    }
    
    public var description: String {
        return """
            inserted: \(inserted)
            updated: \(updated)
            conflicts: \(conflicts)
            pulled: \(pulled)
            pushed: \(pushed)
        """
    }
}
