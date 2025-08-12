//
//  WelcomeView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/16/25.
//

import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to Zunlo!")
                .themedLargeTitle()
            Text("Let’s set up your experience.")
                .themedHeadline()
            Button("Get Started", action: onContinue)
                .themedSecondaryButton()
        }
        .defaultBackground()
        .padding()
    }
}
