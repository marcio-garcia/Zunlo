//
//  DateExtraction.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 8/31/25.
//

// MARK: - Date Extraction

import Foundation

public struct DateParseResult {
    public var dates: [Date] = []
    public var ranges: [Range<Date>] = []
}

public func extractDates(_ text: String, locale: Locale = .current) -> DateParseResult {
    let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    var out = DateParseResult()
    let ns = text as NSString
    detector.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: ns.length)) { match, _, _ in
        guard let m = match, m.resultType == .date else { return }
        let dur = m.duration
        if #available(iOS 16.0, *), let start = m.date {
            out.ranges.append(start..<(start.addingTimeInterval(dur)))
        } else if let d = m.date {
            out.dates.append(d)
        }
    }
    return out
}
