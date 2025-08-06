//
//  FallbackView.swift
//  FlowNavigator
//
//  Created by Marcio Garcia on 8/4/25.
//

import SwiftUI

public struct FallbackView: View {
    let message: String
    let nav: AppNavigationManager
    let viewID: UUID

    public init(message: String, nav: AppNavigationManager, viewID: UUID) {
        self.message = message
        self.nav = nav
        self.viewID = viewID
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            Text(message)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)

            Button("Dismiss") {
                nav.dismissSheet(for: viewID)
                nav.dismissFullScreen(for: viewID)
                nav.dismissDialog(for: viewID)
                nav.popToRoot(for: viewID)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
