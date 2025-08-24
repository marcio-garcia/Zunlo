//
//  View+Error.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/19/25.
//

import SwiftUI
import GlowUI

extension View {
    func errorAlert(_ handler: ErrorHandler) -> some View {
        self.modifier(ErrorAlertModifier(handler: handler))
    }
}

struct ErrorAlertModifier: ViewModifier {
    @ObservedObject var handler: ErrorHandler
    @State var toast: Toast?
    
    func body(content: Content) -> some View {
        content
            .toast(Binding<Toast?>(
                get: {
                    if let msg = handler.message {
                        return Toast(msg)
                    }
                    return nil
                },
                set: { newValue in
                    if newValue == nil {
                        DispatchQueue.main.async {
                            handler.clear()
                        }
                    }
                }
            ))
//            .alert("Error", isPresented: Binding<Bool>(
//                get: { handler.message != nil },
//                set: { newValue in
//                    if !newValue {
//                        DispatchQueue.main.async {
//                            handler.clear()
//                        }
//                    }
//                }
//            )) {
//                Button("Ok", role: .cancel) {}
//            } message: {
//                Text(handler.message ?? "Unknown error")
//            }
    }
}
