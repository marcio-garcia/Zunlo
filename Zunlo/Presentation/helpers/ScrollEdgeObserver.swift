//
//  ScrollEdgeObserver.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/27/25.
//

import SwiftUI

enum ScrollEdge {
    case top
    case bottom
}

struct ScrollEdgePreferenceKey: PreferenceKey {
    static var defaultValue: [ScrollEdge: CGFloat] = [:]

    static func reduce(value: inout [ScrollEdge: CGFloat], nextValue: () -> [ScrollEdge: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct ScrollEdgeObserver: ViewModifier {
    let onEdgeNearTop: () -> Void
    let onEdgeNearBottom: () -> Void

    @State private var hasScrolledOnce = false
    
    func body(content: Content) -> some View {
        content
            .background(GeometryReader { geo in
                Color.clear
                    .preference(key: ScrollEdgePreferenceKey.self, value: [.top: geo.frame(in: .global).minY])
            }.frame(height: 0), alignment: .top)
            .background(GeometryReader { geo in
                Color.clear
                    .preference(key: ScrollEdgePreferenceKey.self, value: [.bottom: geo.frame(in: .global).minY])
            }.frame(height: 0), alignment: .bottom)
            .onPreferenceChange(ScrollEdgePreferenceKey.self) { values in
                let top = values[.top] ?? 0
                let bottom = values[.bottom] ?? 0
                let screenHeight = UIScreen.main.bounds.height

    
                // Detect real scroll activity once
                if !hasScrolledOnce, abs(top) > 400 {
                    hasScrolledOnce = true
                }
                
                // Skip initial trigger until scroll has moved
                guard hasScrolledOnce else { return }
                
                if top > -screenHeight * 2 {
                    onEdgeNearTop()
                } else if bottom < screenHeight * 2.5 {
                    onEdgeNearBottom()
                }
            }
    }
}

extension View {
    func scrollEdgeObserver(
        onEdgeNearTop: @escaping () -> Void,
        onEdgeNearBottom: @escaping () -> Void
    ) -> some View {
        self.modifier(
            ScrollEdgeObserver(
                onEdgeNearTop: onEdgeNearTop,
                onEdgeNearBottom: onEdgeNearBottom
            )
        )
    }
}
