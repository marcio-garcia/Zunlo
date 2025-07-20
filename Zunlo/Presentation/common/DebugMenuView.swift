//
//  DebugMenuView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/20/25.
//

import SwiftUI

struct DebugMenuView: View {
    @EnvironmentObject var upgradeReminderManager: UpgradeReminderManager

    var body: some View {
        Form {
            Section(header: Text("Upgrade Reminder")) {
                Button("Reset Upgrade Reminder") {
                    upgradeReminderManager.resetReminderDebug()
                }
                Button("Simulate Reminder Conditions") {
                    UserDefaults.standard.set(Date().addingTimeInterval(-4 * 86400).timeIntervalSince1970, forKey: "firstLaunchTimestamp")
                    UserDefaults.standard.set(10, forKey: "sessionCount")
                    UserDefaults.standard.set(false, forKey: "hasDismissedUpgradeReminder")
                }
            }

            // Add other debug tools here if needed
        }
        .navigationTitle("Debug Menu")
    }
}
