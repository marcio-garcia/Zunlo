//
//  ShakeEffect.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/8/25.
//

import SwiftUI

struct ShakeEffect: GeometryEffect {
    var shakes: Int
    var amplitude: CGFloat = 6
    var animatableData: CGFloat

    init(shakes: Int) {
        self.shakes = shakes
        self.animatableData = CGFloat(shakes)
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = sin(animatableData * .pi * 2) * amplitude
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}
