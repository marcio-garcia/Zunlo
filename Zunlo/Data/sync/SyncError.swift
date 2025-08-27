//
//  SyncError.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/26/25.
//

import Foundation
import Supabase

// Wrap non-2xx HTTP responses so we always have a status code.
struct HTTPStatusError: Error {
    let status: Int
    let body: Data?
}

enum SyncError: Error {
    case message(String)
}

// High-level categories for sync decisions.
enum FailureKind {
    case conflict              // 409/412, or guarded update returned 0 rows
    case missing               // 404 (server row gone)
    case rateLimited(retryAfter: TimeInterval?) // 429 or 503 w/ Retry-After if you expose it
    case transient             // 5xx, network/URLError, timeouts
    case permanent             // 4xx validation/RLS, decoding, etc.
}

// Turn any Error into a FailureKind.
func classify(_ error: Error) -> FailureKind {
    if let http = error as? HTTPStatusError {
        switch http.status {
        case 409, 412: return .conflict
        case 404:      return .missing
        case 408, 429: return .rateLimited(retryAfter: nil)
        case 500..<600:return .transient
        default:       return .permanent
        }
    }
    if let urlErr = error as? URLError {
        switch urlErr.code {
        case .timedOut, .cannotFindHost, .cannotConnectToHost,
             .networkConnectionLost, .dnsLookupFailed, .notConnectedToInternet:
            return .transient
        default:
            return .transient
        }
    }
    if error is DecodingError {
        return .permanent
    }
    return .permanent
}
