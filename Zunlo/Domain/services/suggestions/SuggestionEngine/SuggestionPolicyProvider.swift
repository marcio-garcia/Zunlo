//
//  SuggestionPolicyProvider.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/12/25.
//

import SwiftUI

@MainActor
final class SuggestionPolicyProvider: ObservableObject {
    @Published var prefs: AvailabilityPrefs {
        didSet { save(prefs) }
    }

    @Published var minFocusDuration: TimeInterval {
        didSet { save(minFocusDuration: minFocusDuration)}
    }
    
    /// Live policy you pass into the engine.
    var policy: SuggestionPolicy {
        SuggestionPolicy.from(prefs)
    }

    init() {
        self.prefs = Self.load()
        self.minFocusDuration = Self.load()
    }

    // MARK: persistence (UserDefaults keys match your earlier AppStorage)
    private static let kStartHour   = "avail.startHour"
    private static let kStartMinute = "avail.startMinute"
    private static let kEndHour     = "avail.endHour"
    private static let kEndMinute   = "avail.endMinute"
    private static let kTZ          = "avail.tz"
    private static let kMinFocusDur = "minFocusDur"

    private static func load() -> AvailabilityPrefs {
        let d = UserDefaults.standard
        return AvailabilityPrefs(
            startHour:   d.object(forKey: kStartHour)   as? Int ?? 8,
            startMinute: d.object(forKey: kStartMinute) as? Int ?? 0,
            endHour:     d.object(forKey: kEndHour)     as? Int ?? 20,
            endMinute:   d.object(forKey: kEndMinute)   as? Int ?? 0,
            timeZoneID:  d.string(forKey: kTZ) ?? TimeZone.current.identifier
        )
    }
    
    private static func load() -> TimeInterval {
        let d = UserDefaults.standard
        return d.object(forKey: kMinFocusDur) as? TimeInterval ?? 15
    }

    private func save(_ p: AvailabilityPrefs) {
        let d = UserDefaults.standard
        d.set(p.startHour,   forKey: Self.kStartHour)
        d.set(p.startMinute, forKey: Self.kStartMinute)
        d.set(p.endHour,     forKey: Self.kEndHour)
        d.set(p.endMinute,   forKey: Self.kEndMinute)
        d.set(p.timeZoneID,  forKey: Self.kTZ)
    }
    
    private func save(minFocusDuration: TimeInterval) {
        let d = UserDefaults.standard
        d.set(minFocusDuration, forKey: Self.kMinFocusDur)
    }

    // Convenience mutation helpers (nice for unit tests too)
    func setStart(hour: Int, minute: Int) { prefs.startHour = hour; prefs.startMinute = minute }
    func setEnd(hour: Int, minute: Int)   { prefs.endHour = hour;   prefs.endMinute = minute }
    func setTimeZone(_ tz: TimeZone)      { prefs.timeZoneID = tz.identifier }
    func setMinFocusDuration(seconds: TimeInterval) { minFocusDuration = seconds }
    
    func utcAvailabilityRanges(
        for date: Date,
        localStartHour: Int, localStartMinute: Int,
        localEndHour: Int, localEndMinute: Int,
        tz: TimeZone
    ) -> [Range<Date>] {
        var cal = Calendar.appDefault
        cal.timeZone = tz

        let sod = cal.startOfDay(for: date)
        let nextMidnight = cal.date(byAdding: .day, value: 1, to: sod)!

        let startLocal = cal.date(bySettingHour: localStartHour, minute: localStartMinute, second: 0, of: sod)!
        let endLocal   = cal.date(bySettingHour: localEndHour,   minute: localEndMinute,   second: 0, of: sod)!

        if endLocal > startLocal {
            return [startLocal..<endLocal]
        } else {
            // Overnight (e.g., 22:00–06:00)
            return [sod..<endLocal, startLocal..<nextMidnight]
        }
    }
}
