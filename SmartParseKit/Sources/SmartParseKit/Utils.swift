//
//  Utils.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 9/3/25.
//

import Foundation

public func weekRange(containing date: Date, calendar: Calendar = .current) -> Range<Date> {
    var start: Date = date
    var interval: TimeInterval = 0
    _ = calendar.dateInterval(of: .weekOfYear, start: &start, interval: &interval, for: date)
    return start..<(start.addingTimeInterval(interval))
}


public func nextWeekRange(from date: Date, calendar: Calendar = .current) -> Range<Date> {
    let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: date)!
    return weekRange(containing: nextWeek, calendar: calendar)
}


public func extractTitle(_ text: String) -> String? {
    // Remove common scaffolding and detected date substrings
    var s = text
    let lowers = [
        "create task","add task","create event","new event","schedule","criar tarefa","criar evento","agendar","marcar","para ","to ","for "
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
