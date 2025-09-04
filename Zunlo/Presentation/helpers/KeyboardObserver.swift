//
//  KeyboardObserver.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/3/25.
//

import UIKit
import Combine

final class KeyboardObserver: ObservableObject {
    @Published private(set) var height: CGFloat = 0
    private var cancellables: Set<AnyCancellable> = []

    init() {
        let willChange = NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
        let willHide   = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)

        willChange
            .merge(with: willHide)
            .sink { [weak self] note in
                guard let self else { return }
                self.height = Self.keyboardHeight(from: note)
            }
            .store(in: &cancellables)
    }

    private static func keyboardHeight(from note: Notification) -> CGFloat {
        guard
            let userInfo = note.userInfo,
            let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
            let window = UIApplication.shared.connectedScenes.compactMap({ scene in
                (scene as? UIWindowScene)?.keyWindow
            }).first
        else { return 0 }

        // Intersection with window so we get the *visible* overlap.
        let converted = window.convert(endFrame, from: nil)
        let overlap = max(0, window.bounds.maxY - converted.minY)

        // Subtract bottom safe area so we don’t double-count the home indicator inset.
        return max(0, overlap - window.safeAreaInsets.bottom)
    }
}
