//
//  UpgradeReminderBanner.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/20/25.
//

import SwiftUI

struct UpgradeReminderBanner: View {
    var onUpgradeTap: () -> Void
    var onDismissTap: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top) {
                Text("You're currently using a guest account. Sign up to keep your tasks synced and backed up forever.")
                    .themedFootnote()
                    .foregroundStyle(Color.gray)

                Spacer()

                Button(action: onDismissTap) {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                }
            }

            Button(action: onUpgradeTap) {
                Text("I want to keep my tasks")
            }
            .themedTertiaryButton()
        }
        .themedBanner()
        .transition(.opacity.combined(with: .slide))
    }
}
