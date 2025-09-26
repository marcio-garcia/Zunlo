//
//  OnboardingLocationView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/9/25.
//

import SwiftUI
import GlowUI

struct LocationPermissionView: View {
    var locationService: LocationService
    let onContinue: () -> Void
    @State var isLoading = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Enable location services for local weather and smart suggestions about when to plan activities.")
                .multilineTextAlignment(.center)
                .themedHeadline()
                .padding(.horizontal, 20)

            Text("Your location data stays private and secure.")
                .themedBody()
                .padding(.horizontal, 20)

            Button("Allow location access") {
                isLoading = true
                locationService.requestPermission()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    onContinue()
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
