//
//  SyncError.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/26/25.
//

import Foundation
import Supabase

// High-level categories for sync decisions.
enum FailureKind {
    case conflict              // 409/412, or guarded update returned 0 rows
    case missing               // 404 (server row gone)
    case rateLimited(retryAfter: TimeInterval?) // 429 or 503 w/ Retry-After if you expose it
    case transient             // 5xx, network/URLError, timeouts
    case permanent             // 4xx validation/RLS, decoding, etc.
}

// Wrap non-2xx HTTP responses so we always have a status code.
struct HTTPStatusError: Error {
    let status: Int
    let body: Data?    
}
