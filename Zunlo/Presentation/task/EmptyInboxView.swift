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
            Text("Your task inbox is empty.")
                .font(.title2)
                .multilineTextAlignment(.center)

            Button(action: onAdd) {
                Label("Add your first task", systemImage: "plus")
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}
