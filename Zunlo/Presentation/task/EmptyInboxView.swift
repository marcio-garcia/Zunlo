//
//  EmptyInboxView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/13/25.
//

import SwiftUI

struct EmptyInboxView: View {
    var onAdd: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "note.text.badge.plus")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundColor(Color.theme.accent)
                .padding(.top, 60)

            Text("No Tasks Yet")
                .themedHeadline()

            Text("Start by adding your first task.")
                .themedBody()
                .multilineTextAlignment(.center)

            Button(action: onAdd) {
                Label("Add your first task", systemImage: "plus.circle.fill")
            }
            .themedPrimaryButton()

            Spacer()
        }
        .padding()
    }
}
