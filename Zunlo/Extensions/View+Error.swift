//
//  View+Error.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/19/25.
//

import SwiftUI
import GlowUI

extension View {
    func errorToast(_ handler: ErrorHandler) -> some View {
        self.modifier(ErrorToastModifier(handler: handler))
    }
}

struct ErrorToastModifier: ViewModifier {
    @ObservedObject var handler: ErrorHandler
    @State private var toast: Toast?    // stable instance while shown

    func body(content: Content) -> some View {
        content
            .toast($toast)               // the toast view reads/writes this
            .onChange(of: handler.message, initial: true) {
                // Create/clear the toast only when the message actually changes
                toast = handler.message.map { Toast($0) }
            }
            .onChange(of: toast) { oldValue, newValue in
                // Dismissed by the toast view -> clear the error source
                if newValue == nil {
                    DispatchQueue.main.async {
                        handler.clear()
                    }
                }
            }
    }
}
