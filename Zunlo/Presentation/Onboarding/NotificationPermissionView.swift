//
//  NotificationPermissionView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/16/25.
//

import SwiftUI

struct NotificationPermissionView: View {
    var pushService: PushNotificationService
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Enable push notifications to get reminders and updates.")
            Button("Allow Notifications") {
                pushService.requestNotificationPermissions { granted in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        onContinue()
                    }
                }
            }
        }
        .padding()
    }
}
