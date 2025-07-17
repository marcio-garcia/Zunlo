//
//  RequestPushPermissionsView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/15/25.
//

import SwiftUI

struct RequestPushPermissionsView: View {
    var pushPermissionsDenied: Bool
    let onRequest: () -> Void
    
    var body: some View {
        if pushPermissionsDenied {
            VStack(spacing: 16) {
                Text("Push Notifications service is not enabled.")
                Text("Please enable it in Settings to use reminder feature.")
                    .font(.caption)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                        onRequest()
                    }
                }
            }
            .padding()
        } else {
            VStack(spacing: 16) {
                Text("To use the reminder feature, you need to accept Push Notifications.")
                    .multilineTextAlignment(.center)
                Button("Allow Push Notifications") {
                    onRequest()
                }
            }
            .padding()
        }
    }
}
