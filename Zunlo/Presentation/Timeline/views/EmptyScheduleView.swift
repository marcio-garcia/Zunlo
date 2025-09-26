//
//  EmptyScheduleView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/5/25.
//

import SwiftUI

struct EmptyScheduleView: View {
    var onAdd: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "calendar.badge.plus")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundColor(Color.theme.accent)

            Text("No Events Yet")
                .themedHeadline()

            Text("Start by adding your first event to your schedule.")
                .themedBody()
                .padding()
                .multilineTextAlignment(.center)

            Button(action: onAdd) {
                Label("Add Event", systemImage: "plus.circle.fill")
            }
            .themedPrimaryButton()

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
