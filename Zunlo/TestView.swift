//
//  TestView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import SwiftUI

struct TestView: View {
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            Text("Hello, ADHD Timeline!")
                .font(.largeTitle)
//                .foregroundColor(.primary) // Should appear black in light mode
        }
    }
}
