//
//  OnboardingLocationView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/9/25.
//

import SwiftUI

//struct OnboardingLocationView: View {
//    let onRequest: () -> Void
//    var body: some View {
//        VStack(spacing: 16) {
//            Text("We use your location to show nearby events and personalize your experience.")
//                .multilineTextAlignment(.center)
//            Button("Allow Location Access") {
//                onRequest()
//            }
//        }
//        .padding()
//    }
//}

struct LocationPermissionView: View {
    var locationService: LocationService
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("We need your location to show local content.")
            Button("Allow Location Access") {
                locationService.requestPermission()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    onContinue()
                }
            }
        }
        .padding()
    }
}
