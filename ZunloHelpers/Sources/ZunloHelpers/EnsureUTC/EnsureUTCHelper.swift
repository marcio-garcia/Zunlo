//
//  EnsureUTCHelper.swift
//  ZunloHelpers
//
//  Created by Marcio Garcia on 8/24/25.
//

import Foundation

public class EnsureUTCHelper {

    // MARK: - Regex helpers

    private static let NAIVE_RE = try! NSRegularExpression(
        pattern: #"^\d{4}-\d{2}-\d{2}(?:[ T]\d{2}:\d{2}(?::\d{2})?)?$"#,
        options: []
    )

    private static let OFFSETED_RE = try! NSRegularExpression(
        pattern: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2})?(?:Z|[+-]\d{2}:\d{2})$"#,
        options: []
    )

    // MARK: - ISO8601 formatters

    nonisolated(unsafe) private static let isoUTCFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.formatOptions = [.withInternetDateTime] // no fractional seconds; outputs ...Z
        return f
    }()

    // Some “with offset” strings may omit seconds; these DateFormatters handle more cases than ISO8601DateFormatter alone.
    private static func makeOffsetParsers() -> [DateFormatter] {
        let tzUTC = TimeZone(secondsFromGMT: 0)!
        let locale = Locale(identifier: "en_US_POSIX")
        let patterns = [
            "yyyy-MM-dd'T'HH:mmXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm'Z'",
            "yyyy-MM-dd'T'HH:mm:ss'Z'"
        ]
        return patterns.map { pattern in
            let df = DateFormatter()
            df.calendar = Calendar(identifier: .gregorian)
            df.locale = locale
            df.timeZone = tzUTC
            df.dateFormat = pattern
            return df
        }
    }

    private static let offsetParsers: [DateFormatter] = makeOffsetParsers()

    // MARK: - Core conversion

    /// Converts a local wall time in `timeZoneId` to a UTC ISO string with 'Z'.
    /// Accepts:
    /// - "YYYY-MM-DD"
    /// - "YYYY-MM-DDTHH:mm"
    /// - "YYYY-MM-DDTHH:mm:ss"
    /// - ISO with 'Z' or numeric offset
    public static func toUtcIso(_ input: String, timeZoneId: String) -> String {
        // Already has offset or Z? Parse & normalize to ...Z
        if OFFSETED_RE.matches(input) {
            if let d = parseOffsetDate(input) {
                return isoUTCFormatter.string(from: d)
            }
            // Fall through if parsing failed unexpectedly
        }

        // Naive local wall time: interpret in provided time zone
        if NAIVE_RE.matches(input) {
            let normalized = input.replacingOccurrences(of: " ", with: "T")
            let parts = normalized.split(separator: "T", maxSplits: 1, omittingEmptySubsequences: false)
            let dateStr = String(parts[0])
            let timeStr = parts.count > 1 ? String(parts[1]) : "00:00:00"

            let datePieces = dateStr.split(separator: "-").compactMap { Int($0) }
            guard datePieces.count == 3 else { return input }
            let (y, m, d) = (datePieces[0], datePieces[1], datePieces[2])

            let timePieces = timeStr.split(separator: ":").map { Int($0) ?? 0 }
            let h = timePieces.indices.contains(0) ? timePieces[0] : 0
            let min = timePieces.indices.contains(1) ? timePieces[1] : 0
            let s = timePieces.indices.contains(2) ? timePieces[2] : 0

            let tz = TimeZone(identifier: timeZoneId) ?? TimeZone(secondsFromGMT: 0)!
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = tz

            // Build “midnight local” then add time components; this is resilient across DST gaps.
            var dayComps = DateComponents()
            dayComps.timeZone = tz
            dayComps.year = y
            dayComps.month = m
            dayComps.day = d

            guard let localStartOfDay = cal.date(from: dayComps) else {
                return input
            }

            var add = DateComponents()
            add.hour = h
            add.minute = min
            add.second = s

            guard let localDateTime = cal.date(byAdding: add, to: localStartOfDay) else {
                return input
            }

            // Format as UTC with trailing 'Z'
            return isoUTCFormatter.string(from: localDateTime)
        }

        // Not a recognized datetime; return unchanged
        return input
    }

    private static func parseOffsetDate(_ s: String) -> Date? {
        // Try ISO8601 first (fast path)
        if let d = ISO8601DateFormatter().date(from: s) { return d }
        // Try flexible DateFormatters that accept missing seconds, etc.
        for df in offsetParsers {
            if let d = df.date(from: s) { return d }
        }
        return nil
    }

    // MARK: - Recursive normalization

    /// Recursively walks arrays/dictionaries and converts any string that looks like a datetime
    /// into UTC ISO (`...Z`). You can optionally limit conversion to specific keys.
    public static func ensureUtcArgs(_ value: Any,
                              tzId: String,
                              onlyKeys: Set<String>? = nil) -> Any {
        // Array: map recursively
        if let arr = value as? [Any] {
            return arr.map { ensureUtcArgs($0, tzId: tzId, onlyKeys: onlyKeys) }
        }

        // Dictionary: normalize values and (optionally) filter by key
        if let dict = value as? [String: Any] {
            var out: [String: Any] = [:]
            out.reserveCapacity(dict.count)
            for (k, v) in dict {
                let keyAllowed = (onlyKeys == nil) || (onlyKeys!.contains(k))
                if let s = v as? String, keyAllowed,
                   NAIVE_RE.matches(s) || OFFSETED_RE.matches(s) {
                    out[k] = toUtcIso(s, timeZoneId: tzId)
                } else {
                    out[k] = ensureUtcArgs(v, tzId: tzId, onlyKeys: onlyKeys)
                }
            }
            return out
        }

        // Primitive: passthrough
        return value
    }

}
