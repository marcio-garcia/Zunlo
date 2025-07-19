//
//  View+Error.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/19/25.
//

import SwiftUI

extension View {
    func errorAlert(_ handler: ErrorHandler) -> some View {
        self.modifier(ErrorAlertModifier(handler: handler))
    }
}

struct ErrorAlertModifier: ViewModifier {
    @ObservedObject var handler: ErrorHandler

    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: Binding<Bool>(
                get: { handler.message != nil },
                set: { if !$0 { handler.clear() } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(handler.message ?? "Unknown error")
            }
    }
}
