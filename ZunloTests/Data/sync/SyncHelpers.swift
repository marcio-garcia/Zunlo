//
//  SyncHelpers.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/27/25.
//

import Foundation
@testable import Zunlo

// MARK: - Test scaffolding (mocks + helpers)

//enum TestError: Error { case conflict, missing, transient, rateLimited }
//enum FailureKind { case conflict, missing, rateLimited(TimeInterval?), transient, permanent }
//func classify(_ error: Error) -> FailureKind {
//    switch error {
//    case TestError.conflict:     return .conflict
//    case TestError.missing:      return .missing
//    case TestError.rateLimited:  return .rateLimited(nil)
//    case TestError.transient:    return .transient
//    default:                     return .permanent
//    }
//}

// Minimal RemoteEntity you already have in app code
//protocol RemoteEntity {
//    var id: UUID { get }
//    var updatedAt: Date { get }
//    var updatedAtRaw: String? { get }
//    var deletedAt: Date? { get }
//    var version: Int? { get }
//}

// A tiny “row” we’ll reuse for multiple entities in tests
struct Row: RemoteEntity, Equatable {
    let id: UUID
    let updatedAt: Date
    let updatedAtRaw: String?
    let deletedAt: Date?
    let version: Int?
    // payload-ish fields
    var title: String
    var parentId: UUID?
    init(id: UUID = UUID(),
         updatedAtRaw: String,
         deletedAt: Date? = nil,
         version: Int? = nil,
         title: String,
         parentId: UUID? = nil) {
        self.id = id
        self.updatedAtRaw = updatedAtRaw
        self.updatedAt = ISO8601DateFormatter().date(from: updatedAtRaw) ?? Date(timeIntervalSince1970: 0)
        self.deletedAt = deletedAt
        self.version = version
        self.title = title
        self.parentId = parentId
    }
}

// Tiny mock “server” that pages by the half-open (ts,id) window using raw timestamp strings
final class MockServer<R: RemoteEntity> {
    // Presorted by (updatedAtRaw, id)
    private(set) var rows: [R] = []

    func seed(_ rows: [R]) {
        self.rows = rows.sorted {
            let a = $0.updatedAtRaw ?? "", b = $1.updatedAtRaw ?? ""
            if a == b { return $0.id.uuidString < $1.id.uuidString }
            return a < b
        }
    }

    func fetchSince(ts: String, id: UUID?, limit: Int) -> [R] {
        let start = rows.firstIndex { r in
            let raw = r.updatedAtRaw ?? ""
            if raw > ts { return true }
            if raw == ts, let id = id { return r.id.uuidString > id.uuidString }
            return false
        } ?? rows.count
        let end = min(rows.count, start + limit)
        return start < end ? Array(rows[start..<end]) : []
    }

    // Mutating helpers (optional for advanced tests)
    func upsert(_ new: [R]) {
        // naive replace by id
        var dict = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        for n in new { dict[n.id] = n }
        seed(Array(dict.values))
    }
}

// In-memory “DB” for tests: holds applied rows + a generic cursor per table
final class MockDB<R: RemoteEntity> {
    var applied: [UUID: R] = [:]
    var cursorTs: Date = Date(timeIntervalSince1970: 0)
    var cursorTsRaw: String? = nil
    var cursorId: UUID? = nil
    var conflicts: [(R, R?)] = []
    var cleaned: Set<UUID> = []

    func applyPage(_ rows: [R]) {
        for r in rows {
            if r.deletedAt != nil {
                applied[r.id] = r // mark tombstone (or remove if you prefer)
            } else {
                applied[r.id] = r
            }
        }
        if let last = rows.last {
            cursorTs = last.updatedAt
            cursorTsRaw = last.updatedAtRaw
            cursorId = last.id
        }
    }
}

// Helpers to make RFC3339 micros (string compare friendly)

@inline(__always)
func ts(_ d: Date) -> String {
    RFC3339MicrosUTC.string(d) // make it RFC3339 micros like "2025-08-26T14:41:09.167235Z"
}

@inline(__always)
func addSecToTS(_ d: Date, sec: TimeInterval) -> String {
//    return ""
    RFC3339MicrosUTC.string(d.addingTimeInterval(sec))
}
