//
//  Codable+Date.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/13/25.
//

import Foundation

extension JSONDecoder {
    static func supabase() -> JSONDecoder {
        let d = JSONDecoder()
        // Accept fractional and non-fractional RFC3339
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
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
}

extension JSONEncoder {
    static func supabase() -> JSONEncoder {
        let e = JSONEncoder()
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        e.dateEncodingStrategy = .custom { date, encoder in
            var c = encoder.singleValueContainer()
            try c.encode(f.string(from: date))
        }
        return e
    }
}
