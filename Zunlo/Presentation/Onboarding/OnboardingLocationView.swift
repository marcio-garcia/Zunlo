//
//  OnboardingLocationView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/9/25.
//

import SwiftUI

struct OnboardingLocationView: View {
    let onRequest: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Text("We use your location to show nearby events and personalize your experience.")
                .multilineTextAlignment(.center)
            Button("Allow Location Access") {
                onRequest()
            }
        }
        .padding()
    }
}
