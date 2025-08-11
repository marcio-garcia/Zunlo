//
//  Shimmer.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/11/25.
//

import SwiftUI

// MARK: - Shimmer Modifier

struct Shimmer: ViewModifier {
    var active: Bool = true
    var speed: Double = 0.8
    var angle: Angle = .degrees(20)
    var bandSize: CGFloat = 0.25
    var baseTint: Color = .gray.opacity(0.25)
    var highlightTint: Color = .white.opacity(0.9)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        let shimmering = active && !reduceMotion

        return content
            // Only add the overlay while active
            .overlay(shimmering ? baseTint : nil)
            .overlay(shimmering ? overlayMask.mask(content) : nil)
            .onAppear { startIfNeeded(shimmering) }
            .onChange(of: shimmering, { oldValue, newValue in
                startIfNeeded(newValue)
            })
            .onDisappear { stop() }
    }

    private func startIfNeeded(_ on: Bool) {
        if on {
            phase = -1
            withAnimation(.linear(duration: speed).repeatForever(autoreverses: false)) {
                phase = 1
            }
        } else {
            stop()
        }
    }

    private func stop() {
        // kill the animation and reset so next start begins off-screen
        withAnimation(.none) {
            phase = -1
        }
    }

    private var overlayMask: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            let rad = CGFloat(angle.radians)
            
            // overscan so rotated gradient always covers
            let coverW = abs(cos(rad)) * w + abs(sin(rad)) * h
            let coverH = abs(sin(rad)) * w + abs(cos(rad)) * h
            let span = max(coverW, coverH) * 2.0

            LinearGradient(
                stops: [
                    .init(color: .clear,      location: (1 - bandSize)/2),
                    .init(color: highlightTint, location: 0.5),
                    .init(color: .clear,      location: (1 + bandSize)/2),
                ],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: span, height: span)
//            .rotationEffect(angle)
            .offset(x: (phase * span) - span/2)
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
        }
    }
}

extension View {
    func shimmer(active: Bool = true,
                 speed: Double = 0.8,
                 angle: Angle = .degrees(20),
                 bandSize: CGFloat = 0.25,
                 baseTint: Color = .gray.opacity(0.25),
                 highlightTint: Color = .white.opacity(0.9)) -> some View {
        modifier(Shimmer(active: active, speed: speed, angle: angle,
                         bandSize: bandSize, baseTint: baseTint, highlightTint: highlightTint))
    }
}

