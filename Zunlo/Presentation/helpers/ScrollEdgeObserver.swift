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

struct DayPositionPreferenceKey: PreferenceKey {
    static var defaultValue: [Date: CGFloat] = [:]

    static func reduce(value: inout [Date: CGFloat], nextValue: () -> [Date: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct ScrollEdgeObserver: ViewModifier {
    let onEdgeNearTop: () -> Void
    let onEdgeNearBottom: () -> Void
    let currentTopDayChanged: (Date) -> Void

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

                if top > -screenHeight * 2 {
                    onEdgeNearTop()
                } else if bottom < screenHeight * 2.5 {
                    onEdgeNearBottom()
                }
            }
            .onPreferenceChange(DayPositionPreferenceKey.self) { positions in
                if let (topDay, _) = positions.min(by: { $0.value < $1.value }) {
                    currentTopDayChanged(topDay)
                }
            }
    }
}

extension View {
    func scrollEdgeObserver(
        onEdgeNearTop: @escaping () -> Void,
        onEdgeNearBottom: @escaping () -> Void,
        currentTopDayChanged: @escaping (Date) -> Void
    ) -> some View {
        self.modifier(
            ScrollEdgeObserver(
                onEdgeNearTop: onEdgeNearTop,
                onEdgeNearBottom: onEdgeNearBottom,
                currentTopDayChanged: currentTopDayChanged
            )
        )
    }
}
