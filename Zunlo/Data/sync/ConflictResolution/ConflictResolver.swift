//
//  ConflictResolver.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/28/25.
//

import Foundation

// JSON enc/dec helpers (lossless for your snake_case payloads)
public func decodeJSON<T: Decodable>(_ json: String, as type: T.Type) throws -> T {
    let data = Data(json.utf8)
    return try JSONDecoder.supabaseMicroFirst().decode(T.self, from: data)
}
public func encodeJSON<T: Encodable>(_ value: T, serverOwnedEncodingStrategy: ServerOwnedEncoding = .exclude) throws -> String {
    let enc = JSONEncoder.supabaseMicro()

    let data = try enc.encode(value)
    return String(data: data, encoding: .utf8)!
}

// Shallow JSON 3-way merge with table-specific rules.
public func json3WayMerge(
    base: [String: Any],
    local: [String: Any],
    remote: [String: Any],
    structuralKeys: Set<String>,         // server always wins on these
    serverOwnedKeys: Set<String>,        // never write these (strip before patch)
    newerWinsKeys: Set<String>,          // if both changed, choose newer side by updatedAt
    localUpdatedAtISO: String?,
    remoteUpdatedAtISO: String?
) -> [String: Any] {
    var out = remote  // start from server to keep structural changes
    let localChanged = diffKeys(from: base, to: local)
    let remoteChanged = diffKeys(from: base, to: remote)

    let localIsNewer: Bool = {
        guard let l = localUpdatedAtISO, let r = remoteUpdatedAtISO else { return false }
        return l > r // RFC3339 compare as strings (micros preserved) works lexicographically
    }()

    let keys = Set(base.keys).union(local.keys).union(remote.keys)
    for k in keys {
        if structuralKeys.contains(k) {
            // keep server’s value
            continue
        }

        let b = base[k], l = local[k], s = remote[k]
        let lCh = localChanged.contains(k)
        let sCh = remoteChanged.contains(k)

        switch (lCh, sCh) {
        case (true, true):
            if newerWinsKeys.contains(k) {
                out[k] = localIsNewer ? l ?? s : s
            } else {
                // default: prefer server on double-edit unless you want localIsNewer
                out[k] = localIsNewer ? l ?? s : s
            }
        case (true, false):
            out[k] = l ?? s
        case (false, true):
            out[k] = s
        case (false, false):
            // unchanged on both sides; keep server (already in out)
            break
        }
    }

    // strip server-owned keys from outgoing patch inputs
    for k in serverOwnedKeys { out.removeValue(forKey: k) }
    return out
}

public func diffKeys(from base: [String: Any], to other: [String: Any]) -> Set<String> {
    var changed: Set<String> = []
    let keys = Set(base.keys).union(other.keys)
    for k in keys {
        let b = base[k], o = other[k]
        if !jsonEqual(b, o) { changed.insert(k) }
    }
    return changed
}

public func jsonEqual(_ a: Any?, _ b: Any?) -> Bool {
    switch (a, b) {
    case (nil, nil): return true
    case (nil, _), (_, nil): return false
    case let (x?, y?):
        // Dicts
        if let dx = x as? [String: Any], let dy = y as? [String: Any] {
            let nx = dx as NSDictionary
            let ny = dy as NSDictionary
            return nx.isEqual(to: dy) && ny.isEqual(to: dx) // symmetric
        }
        // Arrays
        if let ax = x as? [Any], let ay = y as? [Any] {
            return NSArray(array: ax).isEqual(to: ay)
        }
        // Nulls
        if x is NSNull, y is NSNull { return true }
        // Strings
        if let sx = x as? String, let sy = y as? String { return sx == sy }
        // Numbers (covers Bool too)
        if let nx = x as? NSNumber, let ny = y as? NSNumber { return nx == ny }
        // Fallback
        return String(describing: x) == String(describing: y)
    }
}

public func toObject(_ json: String) -> [String: Any] {
    (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] ?? [:]
}

public func toJSON(_ obj: [String: Any]) -> String {
    guard JSONSerialization.isValidJSONObject(obj),
          let data = try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys])
    else { return "{}" }
    return String(data: data, encoding: .utf8) ?? "{}"
}
