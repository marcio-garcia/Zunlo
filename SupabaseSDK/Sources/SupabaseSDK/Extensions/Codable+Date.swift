//
//  Codable+Date.swift
//  SupabaseSDK
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
}
