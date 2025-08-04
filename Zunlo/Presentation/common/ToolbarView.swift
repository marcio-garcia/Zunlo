//
//  ToolbarView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/3/25.
//

import SwiftUI

struct ToolbarView<Leading: View, Center: View, Trailing: View>: View {
    let blurStyle: UIBlurEffect.Style?
    let leading: Leading
    let center: Center
    let trailing: Trailing

    init(
        blurStyle: UIBlurEffect.Style? = .systemMaterial,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder center: () -> Center,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.blurStyle = blurStyle
        self.leading = leading()
        self.center = center()
        self.trailing = trailing()
    }

    var body: some View {
        ZStack {
            if let style = blurStyle {
                BlurView(style: style)
                    .edgesIgnoringSafeArea(.all)
            }

            HStack {
                leading
                Spacer()
                trailing
            }
            .padding(.horizontal)
            
            HStack {
                Spacer()
                center
                Spacer()
            }
            .padding(.horizontal)
        }
        .frame(height: 44)
    }
}
