//
//  RequestPushPermissionsView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/15/25.
//

import SwiftUI

struct RequestPushPermissionsView: View {
    let onRequest: () -> Void
    var body: some View {
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
