//
//  Utils.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 9/3/25.
//

import Foundation

@inline(__always)
func weekRange(containing date: Date, calendar: Calendar = .current) -> Range<Date> {
    var start = Date()
    var interval: TimeInterval = 0
    _ = calendar.dateInterval(of: .weekOfYear, start: &start, interval: &interval, for: date)
    return start..<(start.addingTimeInterval(interval))
}

@inline(__always)
func nextWeekRange(from date: Date, calendar: Calendar = .current) -> Range<Date> {
    let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: date)!
    return weekRange(containing: nextWeek, calendar: calendar)
}

func extractTitle(_ text: String) -> String? {
    // Remove common scaffolding and detected date substrings
    var s = text
    let lowers = [
        "create task","add task","create event","new event","add event","schedule","criar tarefa","criar evento","agendar","marcar","para ","to ","for "
    ]
    for k in lowers { s = s.replacingOccurrences(of: k, with: "", options: [.caseInsensitive]) }
    
    
    let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    var cut = s
    let ns = s as NSString
    detector.enumerateMatches(in: s, options: [], range: NSRange(location: 0, length: ns.length)) { match, _, _ in
        guard let m = match else { return }
        if let r = Range(m.range, in: cut) { cut.removeSubrange(r) }
    }
    
    
    let drop: Set<String> = ["the","a","an","my","today","tomorrow","tonight","this","next","at","on","to","for","o","a","um","uma","meu","minha","hoje","amanhã","às","este","esta","próxima","próximo","no","na"]
    let title = cut.split{ !$0.isLetter && !$0.isNumber && $0 != " " }.joined().split(separator: " ").filter { !drop.contains($0.lowercased()) }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    return title.isEmpty ? nil : title
}

@inline(__always)
func applyTime(calendar: Calendar, of source: Date, toDayOf day: Date) -> Date {
    let comps = calendar.dateComponents([.hour, .minute, .second], from: source)
    var dayComps = calendar.dateComponents([.year, .month, .day], from: day)
    dayComps.hour = comps.hour
    dayComps.minute = comps.minute
    dayComps.second = comps.second
    return calendar.date(from: dayComps) ?? day
}

@inline(__always)
func substring(_ s: String, _ ns: NSRange) -> String {
    guard ns.location != NSNotFound, let r = Range(ns, in: s) else { return "" }
    return String(s[r])
}

@inline(__always)
func matchesAny(_ token: String, in set: [String]) -> Bool {
    let t = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return set.contains { t == $0.lowercased() }
}

func containsAny(in s: String, of words: [String]) -> Bool {
    let l = s.lowercased()
    return words.contains { l.contains($0.lowercased()) }
}

// De-dup: prefer earlier textual range; unify exact same (date, duration) & overlapping ranges.
func dedup(_ items: [HumanDateDetector.Match], text: String) -> [HumanDateDetector.Match] {
    var out: [HumanDateDetector.Match] = []
    for m in items {
        appendUnique(&out, m, text: text)
    }
    return out
}

func appendUnique(_ arr: inout [HumanDateDetector.Match], _ m: HumanDateDetector.Match, text: String) {
    let k1 = m.date.timeIntervalSinceReferenceDate
    let k2 = m.duration ?? -1
    let nsR = NSRange(m.range, in: text)
    for e in arr {
        let sameTime = abs(e.date.timeIntervalSinceReferenceDate - k1) < 0.5
        let sameDur  = ((e.duration ?? -1) - k2).magnitude < 0.5
        let overlap  = NSIntersectionRange(NSRange(e.range, in: text), nsR).length > 0
        if (sameTime && sameDur) || overlap { return } // skip duplicate-ish
    }
    arr.append(m)
}
