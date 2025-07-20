//
//  UpgradeReminderManager.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/20/25.
//

import Foundation
import SwiftUI

final class UpgradeReminderManager: ObservableObject {
    @AppStorage("firstLaunchTimestamp") private var firstLaunchTimestamp: Double = 0
    @AppStorage("sessionCount") private var sessionCount: Int = 0
    @AppStorage("hasDismissedUpgradeReminder") private var hasDismissed: Bool = false

    /// Minimum number of sessions before showing the banner
    private let minSessions = 3

    /// Minimum number of days since first launch before showing the banner
    private let minDays = 2

    /// Should be called at app launch
    func recordSessionIfNeeded() {
        if firstLaunchTimestamp == 0 {
            firstLaunchTimestamp = Date().timeIntervalSince1970
        }
        sessionCount += 1
    }

    /// Call when the user taps "Dismiss" on the banner
    func dismissReminder() {
        hasDismissed = true
    }

    /// Whether the upgrade reminder should be shown
    func shouldShowReminder(isAnonymous: Bool) -> Bool {
        guard isAnonymous, !hasDismissed else { return false }

        let elapsedDays = Date().timeIntervalSince1970 - firstLaunchTimestamp
        return sessionCount >= minSessions &&
               elapsedDays >= Double(minDays * 24 * 60 * 60)
    }
}

#if DEBUG
extension UpgradeReminderManager {
    func resetReminderDebug() {
        firstLaunchTimestamp = 0
        sessionCount = 0
        hasDismissed = false
    }
}
#endif
