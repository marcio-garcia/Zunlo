//
//  View+DismissModifiers.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/8/25.
//

import SwiftUI

extension View {
    func swipeToDismiss(
        isPresented: Binding<Bool>,
        direction: SwipeDirection = .right,
        threshold: CGFloat = 100,
        predictedThreshold: CGFloat = 200,
        enableFade: Bool = true,
        minOpacity: CGFloat = 0.5
    ) -> some View {
        self.modifier(SwipeToDismissModifier(
            isPresented: isPresented,
            direction: direction,
            threshold: threshold,
            predictedThreshold: predictedThreshold,
            enableFade: enableFade,
            minOpacity: minOpacity
        ))
    }

    func swipeToPop(
        direction: SwipeDirection = .right,
        threshold: CGFloat = 100,
        predictedThreshold: CGFloat = 200,
        enableFade: Bool = false,
        minOpacity: CGFloat = 0.5,
        onDismiss: @escaping () -> Void
    ) -> some View {
        self.modifier(SwipeToPopModifier(
            direction: direction,
            threshold: threshold,
            predictedThreshold: predictedThreshold,
            enableFade: enableFade,
            minOpacity: minOpacity,
            onDismiss: onDismiss
        ))
    }
}
