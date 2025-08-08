//
//  SwipeToDismissModifier.swift
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

struct SwipeToDismissModifier: ViewModifier {
    @Binding var isPresented: Bool

    let direction: SwipeDirection
    let threshold: CGFloat
    let predictedThreshold: CGFloat
    let enableFade: Bool
    let minOpacity: CGFloat
    let onDismiss: (() -> Void)?

    @GestureState private var dragOffset: CGSize = .zero

    init(
        isPresented: Binding<Bool>,
        direction: SwipeDirection = .right,
        threshold: CGFloat = 100,
        predictedThreshold: CGFloat = 200,
        enableFade: Bool = true,
        minOpacity: CGFloat = 0.5,
        onDismiss: (() -> Void)? = nil
    ) {
        _isPresented = isPresented
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
                        state = value.translation
                    }
                    .onEnded { value in
                        let shouldDismiss =
                            direction.allows(value.translation.width) &&
                            (abs(value.translation.width) > threshold ||
                             abs(value.predictedEndTranslation.width) > predictedThreshold)

                        if shouldDismiss {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                                isPresented = false
                                onDismiss?()
                            }
                        }
                    }
            )
    }
}

extension View {
    func swipeToDismiss(
        isPresented: Binding<Bool>,
        direction: SwipeDirection = .right,
        threshold: CGFloat = 100,
        predictedThreshold: CGFloat = 200,
        enableFade: Bool = true,
        minOpacity: CGFloat = 0.5,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        self.modifier(SwipeToDismissModifier(
            isPresented: isPresented,
            direction: direction,
            threshold: threshold,
            predictedThreshold: predictedThreshold,
            enableFade: enableFade,
            minOpacity: minOpacity,
            onDismiss: onDismiss
        ))
    }
}
