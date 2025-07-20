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
            Image(systemName: "calendar.badge.plus")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundColor(.accentColor)
                .padding(.top, 60)

            Text("No Events Yet")
                .themedHeadline()

            Text("Start by adding your first event to your schedule.")
                .themedBody()
                .multilineTextAlignment(.center)

            Button(action: onAdd) {
                Label("Add Event", systemImage: "plus.circle.fill")
            }
            .themedPrimaryButton()

            Spacer()
        }
        .padding()
    }
}
