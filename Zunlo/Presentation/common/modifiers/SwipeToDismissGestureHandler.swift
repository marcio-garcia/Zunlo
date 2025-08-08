//
//  SwipeToDismissGestureHandler.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/8/25.
//

import SwiftUI

enum SwipeDirection {
    case right
    case left
    case both

    func allows(_ translation: CGFloat) -> Bool {
        switch self {
        case .right: return translation > 0
        case .left: return translation < 0
        case .both: return true
        }
    }
}

struct SwipeToDismissGestureHandler: ViewModifier {
    @GestureState private var dragOffset: CGSize = .zero

    let direction: SwipeDirection
    let threshold: CGFloat
    let predictedThreshold: CGFloat
    let enableFade: Bool
    let minOpacity: CGFloat
    let onDismiss: () -> Void

    init(
        direction: SwipeDirection,
        threshold: CGFloat,
        predictedThreshold: CGFloat,
        enableFade: Bool,
        minOpacity: CGFloat,
        onDismiss: @escaping () -> Void
    ) {
        self.direction = direction
        self.threshold = threshold
        self.predictedThreshold = predictedThreshold
        self.enableFade = enableFade
        self.minOpacity = minOpacity
        self.onDismiss = onDismiss
    }
    
    func body(content: Content) -> some View {
        content
            .offset(x: direction.allows(dragOffset.width) ? dragOffset.width : 0)
            .opacity(
                enableFade
                ? max(minOpacity, 1.0 - abs(dragOffset.width / 300.0))
                : 1.0
            )
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        if enableFade {
                            state = value.translation
                        }
                    }
                    .onEnded { value in
                        let shouldDismiss =
                            direction.allows(value.translation.width) &&
                            (abs(value.translation.width) > threshold ||
                             abs(value.predictedEndTranslation.width) > predictedThreshold)

                        print("threshold = \(threshold): \(abs(value.translation.width))")
                        print("predictedThreshold = \(predictedThreshold): \(abs(value.predictedEndTranslation.width))")
                        if shouldDismiss {
//                            withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                                onDismiss()
//                            }
                        }
                    }
            )
    }
}
