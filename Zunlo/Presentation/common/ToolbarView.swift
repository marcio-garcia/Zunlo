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
        VStack(spacing: 0) {
            ZStack {
                if let style = blurStyle {
                    BlurView(style: style)
                        .edgesIgnoringSafeArea(.all)
                }
                
                VStack {
                    Spacer()
                    ZStack {
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
            .frame(height: 88)
            .ignoresSafeArea()
            .shadow(color: .black.opacity(0.1), radius: 12)
            
            Spacer()
        }
    }
}
