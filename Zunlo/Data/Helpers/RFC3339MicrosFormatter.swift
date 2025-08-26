//
//  DateFormatter+iso8601.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/6/25.
//

import Foundation

/// Pattern A — Thread-local cached formatters (recommended for Codable)
/// Each thread gets its own formatter instance. It’s fast (no locks), safe, and works inside init(from:)/encode(to:).
enum RFC3339MicrosUTC {
    // Thread-local builder
    private static func threadFormatter(key: String, build: () -> DateFormatter) -> DateFormatter {
        let dict = Thread.current.threadDictionary
        if let df = dict[key] as? DateFormatter { return df }
        let df = build()
        dict[key] = df
        return df
    }

    // Encoder: always 6 fractional digits + Z
    private static func makeEncoder() -> DateFormatter {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .iso8601)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        return df
    }

    // Decoders: tolerate variants
    private static func makeDecoder(_ fmt: String) -> DateFormatter {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .iso8601)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = fmt
        return df
    }

    private static var decoderFormats: [String] = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX", // micros + offset
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",  // micros + Z
        "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",   // millis + offset
        "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",     // millis + Z
        "yyyy-MM-dd'T'HH:mm:ssXXXXX",       // seconds + offset
        "yyyy-MM-dd'T'HH:mm:ss'Z'"          // seconds + Z
    ]

    static func string(_ date: Date) -> String {
        let enc = threadFormatter(key: "fmt.rfc3339micros.enc", build: makeEncoder)
        return enc.string(from: date)
    }

    static func parse(_ s: String) -> Date? {
        // Cache each decoder per-thread too
        for (i, fmt) in decoderFormats.enumerated() {
            let key = "fmt.rfc3339micros.dec.\(i)"
            let df = threadFormatter(key: key) { makeDecoder(fmt) }
            if let d = df.date(from: s) { return d }
        }
        return nil
    }
}

/// Pattern B — Actor-serialized formatter (nice for general async helpers)
/// Note: you can’t call an actor from inside init(from:) or encode(to:) (they’re sync).
/// So Pattern B is for other async code (e.g., building query strings in your pull loop). Keep Pattern A for Codable.
actor RFC3339MicrosActor {
    private let enc: DateFormatter = {
        let df = DateFormatter()
        df.calendar = .init(identifier: .iso8601)
        df.locale = .init(identifier: "en_US_POSIX")
        df.timeZone = .init(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        return df
    }()

    private let decs: [DateFormatter] = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
        "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
        "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
        "yyyy-MM-dd'T'HH:mm:ssXXXXX",
        "yyyy-MM-dd'T'HH:mm:ss'Z'"
    ].map { fmt in
        let df = DateFormatter()
        df.calendar = .init(identifier: .iso8601)
        df.locale = .init(identifier: "en_US_POSIX")
        df.timeZone = .init(secondsFromGMT: 0)
        df.dateFormat = fmt
        return df
    }

    func string(_ d: Date) -> String { enc.string(from: d) }
    func parse(_ s: String) -> Date? { for df in decs { if let d = df.date(from: s) { return d } }; return nil }
}
