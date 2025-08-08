//
//  SwipeToPopModifier.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/8/25.
//

import SwiftUI

struct SwipeToPopModifier: ViewModifier {
    let direction: SwipeDirection
    let threshold: CGFloat
    let predictedThreshold: CGFloat
    let enableFade: Bool
    let minOpacity: CGFloat
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        content.modifier(
            SwipeToDismissGestureHandler(
                direction: direction,
                threshold: threshold,
                predictedThreshold: predictedThreshold,
                enableFade: enableFade,
                minOpacity: minOpacity,
                onDismiss: onDismiss
            )
        )
    }
}
