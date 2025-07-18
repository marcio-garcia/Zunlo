//
//  TagCloudView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/18/25.
//

import SwiftUI

struct TagCloudView: View {
    let tags: [String]
    
    var body: some View {
        FlexibleView(data: tags, spacing: 8, alignment: .leading) { tag in
            Text(tag)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.accentColor.opacity(0.2)))
                .foregroundColor(Color.accentColor)
                .font(.subheadline)
        }
    }
}
