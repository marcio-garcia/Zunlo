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

    public init(message: String, nav: AppNavigationManager) {
        self.message = message
        self.nav = nav
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            Text(message)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)

            Button("Dismiss") {
                nav.dismissSheet()
                nav.dismissFullScreen()
                nav.dismissDialog()
                nav.popToRoot()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
