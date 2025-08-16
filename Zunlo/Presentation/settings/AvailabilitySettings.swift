//
//  AvailabilitySettings.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/12/25.
//

import SwiftUI

struct AvailabilitySettings: View {
    @EnvironmentObject var policyProvider: SuggestionPolicyProvider
    
    private var tz: TimeZone { policyProvider.prefs.timeZone }
    private let anchor = ISO8601DateFormatter().date(from: "2025-01-01T00:00:00Z")!
    
    var body: some View {
        // Time Zone
        HStack {
            Text("Time Zone").themedBody()
            Spacer()
            Menu(TimeZone.localizedName(for: tz)) {
                Button("\(TimeZone.current.identifier) (Device)") {
                    policyProvider.setTimeZone(TimeZone.current)
                }
                Button("UTC") { policyProvider.setTimeZone(.gmt) }
            }
            .themedBody()
        }
        
        // Start
        DatePicker("Start",
                   selection: Binding<Date>(
                    get: { dateFromHM(hour: policyProvider.prefs.startHour,
                                      minute: policyProvider.prefs.startMinute,
                                      tz: tz, anchor: anchor) },
                    set: { d in let (h,m) = hmFrom(d, tz); policyProvider.setStart(hour: h, minute: m) }),
                   displayedComponents: .hourAndMinute)
        .environment(\.timeZone, tz)
        
        // End
        DatePicker("End",
                   selection: Binding<Date>(
                    get: { dateFromHM(hour: policyProvider.prefs.endHour,
                                      minute: policyProvider.prefs.endMinute,
                                      tz: tz, anchor: anchor) },
                    set: { d in let (h,m) = hmFrom(d, tz); policyProvider.setEnd(hour: h, minute: m) }),
                   displayedComponents: .hourAndMinute)
        .environment(\.timeZone, tz)
        
        // Presets
        HStack {
            Button("Day 8–20") { policyProvider.prefs = .init(startHour: 8,  startMinute: 0,
                                                              endHour: 20, endMinute: 0,
                                                              timeZoneID: tz.identifier) }
            .themedSecondaryButton()
            Spacer()
            Button("Early 7–15") { policyProvider.setStart(hour: 7, minute: 0); policyProvider.setEnd(hour: 15, minute: 0) }
                .themedSecondaryButton()
            Spacer()
            Button("Night 22–6") { policyProvider.setStart(hour: 22, minute: 0); policyProvider.setEnd(hour: 6, minute: 0) }
                .themedSecondaryButton()
        }
        
        // UTC preview for today (handy to check your UTC engine behavior)
        VStack(alignment: .leading, spacing: 4) {
            Text("Today in UTC").themedBody()
            let r = policyProvider.utcAvailabilityRanges(
                for: Date(),
                localStartHour: policyProvider.prefs.startHour,
                localStartMinute: policyProvider.prefs.startMinute,
                localEndHour: policyProvider.prefs.endHour,
                localEndMinute: policyProvider.prefs.endMinute,
                tz: tz
            )
            ForEach(Array(r.enumerated()), id: \.offset) { _, range in
                HStack {
                    Text(range.lowerBound.formatted(date: .omitted, time: .shortened))
                    Text("–")
                    Text(range.upperBound.formatted(date: .omitted, time: .shortened))
                }
                .environment(\.timeZone, .gmt)
                .themedBody()
            }
        }
        .padding(.top, 8)
        
        if isOvernight(startH: policyProvider.prefs.startHour,
                       startM: policyProvider.prefs.startMinute,
                       endH: policyProvider.prefs.endHour,
                       endM: policyProvider.prefs.endMinute) {
            Text("Ends next day (overnight window).").foregroundStyle(.secondary)
        }
    }
    
    // MARK: helpers
    private func isOvernight(startH: Int, startM: Int, endH: Int, endM: Int) -> Bool {
        endH < startH || (endH == startH && endM <= startM)
    }
    private func dateFromHM(hour: Int, minute: Int, tz: TimeZone, anchor: Date) -> Date {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        let sod = cal.startOfDay(for: anchor)
        return cal.date(bySettingHour: hour, minute: minute, second: 0, of: sod)!
    }
    private func hmFrom(_ date: Date, _ tz: TimeZone) -> (Int, Int) {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        let c = cal.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0, c.minute ?? 0)
    }
}

private extension TimeZone {
    static func localizedName(for tz: TimeZone) -> String { tz.identifier }
}
