//
//  CartoonImageHeader.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/8/25.
//

import SwiftUI

struct CartoonImageHeader: View {
    let title: String
    let imageName: String

    var body: some View {
        ZStack(alignment: .leading) {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(height: 200)
                .clipped()
                .blur(radius: 0)

            VStack {
                HStack(spacing: 14) {
                    Text(title)
                        .font(.largeTitle)
                        .foregroundColor(.black)
                        .shadow(color: .white.opacity(0.7), radius: 0.5, x: 1, y: 1)
                    Spacer()
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding(.vertical, 20)
        }
        .frame(height: 200)
        .padding(.vertical, 20)
        .padding(.horizontal, 0)
    }
}
