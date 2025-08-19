//
//  Codable+Date.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/13/25.
//

import Foundation

extension JSONDecoder {
    static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        // Accept fractional and non-fractional RFC3339
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let dt = f.date(from: s) { return dt }
            // try again without fractional seconds
            let g = ISO8601DateFormatter()
            g.formatOptions = [.withInternetDateTime]
            if let dt = g.date(from: s) { return dt }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Bad RFC3339 date: \(s)"))
        }
        return d
    }
    
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
    static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .custom { date, encoder in
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var c = encoder.singleValueContainer()
            try c.encode(f.string(from: date))
        }
        return e
    }
    
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
