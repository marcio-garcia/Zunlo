//
//  Reschedule.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 8/31/25.
//

//import Foundation
//
//// MARK: - Reschedule Target Selection
//
//public struct RescheduleHints {
//    public var preferredDate: Date?
//    public var keywords: [String]
//    
//    public init(preferredDate: Date? = nil, keywords: [String]) {
//        self.preferredDate = preferredDate
//        self.keywords = keywords
//    }
//    
//}
//
//public func selectEventToReschedule<E: EventType>(events: [E], hints: RescheduleHints, calendar: Calendar = .current) -> E? {
//    guard !events.isEmpty else { return nil }
//    let ranked = events.map { ($0, score(event: $0, hints: hints, calendar: calendar)) }.sorted { $0.1 > $1.1 }
//    return ranked.first?.0
//}
//
//private func score<E: EventType>(event: E, hints: RescheduleHints, calendar: Calendar) -> Double {
//    var score: Double = 0
//    let title = event.title.lowercased()
//    for kw in hints.keywords { if title.contains(kw) { score += 0.6 } }
//    if let pref = hints.preferredDate, calendar.isDate(event.startDate, inSameDayAs: pref) { score += 0.7 }
//    if event.isRecurring { score += 0.2 }
//    return score
//}
