//
//  FloatingSearchBar.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import SwiftUI

struct FloatingSearchBar: View {
    let namespace: Namespace.ID
    let onTap: () -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: onTap) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Ask your assistant...")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6))
                    )
                    .matchedGeometryEffect(id: "chatBar", in: namespace)
                    .shadow(radius: 2)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
    }
}
