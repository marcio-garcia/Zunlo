//
//  Codable+Date.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/13/25.
//

import Foundation

extension JSONDecoder {
    /// Prefer microsecond precision; fall back to ISO8601 with/without fractional
    static func supabaseMicroFirst() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { dec in
            let s = try dec.singleValueContainer().decode(String.self)
            // Try lossless first, then ISO (ms), then ISO (no frac)
            if let dt = RFC3339Lossless.parse(s) { return dt }
            if let dt = RFC3339.isoMillis.date(from: s) { return dt }
            if let dt = RFC3339.isoNoFrac.date(from: s) { return dt }
            throw DecodingError.dataCorrupted(.init(codingPath: dec.codingPath,
                                                    debugDescription: "Bad RFC3339 date: \(s)"))
        }
        return d
    }
}

extension JSONEncoder {
    /// Always write 6 fractional digits
    static func supabaseMicro() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .custom { date, enc in
            var c = enc.singleValueContainer()
            try c.encode(date.rfc3339MicroString())
        }
        return e
    }
}
