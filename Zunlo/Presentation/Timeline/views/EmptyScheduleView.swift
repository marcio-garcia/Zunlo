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
                .font(.title2)
                .fontWeight(.semibold)

            Text("Start by adding your first event to your schedule.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: onAdd) {
                Label("Add Event", systemImage: "plus.circle.fill")
                    .font(.title3.bold())
                    .padding(.horizontal, 36)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.accentColor.opacity(0.1)))
            }
            .accentColor(.accentColor)

            Spacer()
        }
        .padding()
    }
}
