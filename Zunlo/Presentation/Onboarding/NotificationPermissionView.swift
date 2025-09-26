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

    @State var isLoading = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Get notified about your tasks so nothing slips through the cracks, plus important app updates.")
                .multilineTextAlignment(.center)
                .themedHeadline()
                .padding(.horizontal, 20)
            Button("Allow Notifications") {
                isLoading = true
                pushService.requestNotificationPermissions { granted in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        onContinue()
                    }
                }
            }
            .themedSecondaryButton()
            .disabled(isLoading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .defaultBackground()
        .padding()
        .onAppear {
            isLoading = false
        }
    }
}
