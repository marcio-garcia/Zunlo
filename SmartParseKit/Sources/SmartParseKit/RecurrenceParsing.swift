//
//  RecurrenceParsing.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 8/31/25.
//

import Foundation

// MARK: - Recurrence Parsing (simplified)

public struct RecurrenceParseResult {
    public enum Frequency { case daily, weekly, monthly, yearly, weekdays, custom }
    public var frequency: Frequency
    public var weekdays: Set<Int>?
    public var timeOfDay: DateComponents?
    public var interval: Int
}

public func parseRecurrence(_ raw: String, locale: Locale = .current) -> RecurrenceParseResult? {
let s = raw.lowercased()


    func timeFromText(_ s: String) -> DateComponents? {
        let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        var comps: DateComponents?
        detector.enumerateMatches(in: s, options: [], range: NSRange(location: 0, length: (s as NSString).length)) { match, _, _ in
            guard let d = match?.date else { return }
            comps = Calendar.current.dateComponents([.hour, .minute], from: d)
        }
        if comps == nil {
            // explicit "14h" or "9:30" pattern
            let p = try! NSRegularExpression(pattern: #"(\\d{1,2})(?:h|:(\\d{2}))"#, options: .caseInsensitive)
            if let m = p.firstMatch(in: s, options: [], range: NSRange(s.startIndex..., in: s)) {
                if let hr = Range(m.range(at: 1), in: s) {
                    let h = Int(s[hr]) ?? 9
                    var min = 0
                    if let mr = Range(m.range(at: 2), in: s) { min = Int(s[mr]) ?? 0 }
                    comps = DateComponents(hour: h, minute: min)
                }
            }
        }
        return comps
    }
    
    
    // weekdays words → set
    let dayMap: [(keys: [String], val: Int)] = [
        (["sunday","domingo"],1),(["monday","segunda","segunda-feira"],2),(["tuesday","terça","terça-feira"],3),
        (["wednesday","quarta","quarta-feira"],4),(["thursday","quinta","quinta-feira"],5),(["friday","sexta","sexta-feira"],6),(["saturday","sábado","sabado"],7)
    ]
    var weekdaySet = Set<Int>()
    for (keys,v) in dayMap { if keys.contains(where: { s.contains($0) }) { weekdaySet.insert(v) } }
    
    
    // interval: "every 2 weeks" / "a cada 2 semanas"
    var interval = 1
    if let r = try? NSRegularExpression(
        pattern: #"(?:every|cada|a cada)\s+(\d{1,2})\s+(?:week|weeks|semana|semanas|day|days|dia|dias|month|months|mês|meses|year|years|ano|anos)"#,
        options: .caseInsensitive),
       let m = r.firstMatch(in: s, options: [], range: NSRange(s.startIndex..., in: s)),
       let rr = Range(m.range(at: 1), in: s) {
        interval = Int(s[rr]) ?? 1
    }
    
    
    let tod = timeFromText(s)
    
    
    if !weekdaySet.isEmpty {
        let freq: RecurrenceParseResult.Frequency = (weekdaySet == [2,3,4,5,6]) ? .weekdays : .weekly
        return RecurrenceParseResult(frequency: freq, weekdays: weekdaySet, timeOfDay: tod, interval: interval)
    }
    if s.contains("every weekday") || s.contains("dias úteis") || s.contains("dia útil") {
        return RecurrenceParseResult(frequency: .weekdays, weekdays: [2,3,4,5,6], timeOfDay: tod, interval: interval)
    }
    if s.contains("every day") || s.contains("diariamente") || s.contains("todos os dias") || s.contains("todo dia") {
        return RecurrenceParseResult(frequency: .daily, weekdays: nil, timeOfDay: tod, interval: interval)
    }
    if s.contains("weekly") || s.contains("every week") || s.contains("semanal") || s.contains("toda semana") {
        return RecurrenceParseResult(frequency: .weekly, weekdays: nil, timeOfDay: tod, interval: interval)
    }
    if s.contains("monthly") || s.contains("every month") || s.contains("mensal") || s.contains("todo mês") {
        return RecurrenceParseResult(frequency: .monthly, weekdays: nil, timeOfDay: tod, interval: interval)
    }
    if s.contains("yearly") || s.contains("every year") || s.contains("anual") || s.contains("todo ano") {
        return RecurrenceParseResult(frequency: .yearly, weekdays: nil, timeOfDay: tod, interval: interval)
    }
    return nil
}
