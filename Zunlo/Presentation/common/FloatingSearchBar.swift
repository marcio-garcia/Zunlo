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
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "bubble.left.and.text.bubble.right")
                                .foregroundColor(.primary)
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
