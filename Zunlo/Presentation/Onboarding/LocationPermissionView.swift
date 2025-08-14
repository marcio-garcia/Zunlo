//
//  OnboardingLocationView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/9/25.
//

import SwiftUI

struct LocationPermissionView: View {
    var locationService: LocationService
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("We need your location to show local content.")
                .themedHeadline()
            Button("Allow Location Access") {
                locationService.requestPermission()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    onContinue()
                }
            }
            .themedSecondaryButton()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .defaultBackground()
        .padding()
    }
}
