//
//  LocationDeniedView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/9/25.
//

import SwiftUI

struct LocationDeniedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Location access denied.")
            Text("Please enable location in Settings to use this app.")
                .font(.caption)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        }
        .padding()
    }
}
