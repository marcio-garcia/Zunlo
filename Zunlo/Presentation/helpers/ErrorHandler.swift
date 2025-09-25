//
//  ErrorHandler.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/19/25.
//

import Foundation
import SupabaseSDK

@MainActor
class ErrorHandler: ObservableObject {
    @Published var message: String?

    func handle(_ error: Error) {
        if let err = error as? SupabaseServiceError {
            message = SupabaseErrorFormatter.format(err)
        } else if let err = error as? EventError {
            message = err.description
        } else if let err = error as? AuthProvidingError {
            handleAuthError(error: err)
        } else if (error as NSError).domain == "io.realm" {
            message = error.localizedDescription
        } else {
            print("Execution error: \(error)")
            message = error.localizedDescription
        }
    }
    
    func handle(_ message: String) {
        self.message = message
    }

    func clear() {
        message = nil
    }
}

extension ErrorHandler {
    private func handleAuthError(error: AuthProvidingError) {
        switch error {
        case .unauthorized:
            message = String(localized: "Sign in to perform this operation")
        case .unableToSignUp(let msg):
            message = msg
        case .confirmEmail(let msg):
            message = msg
        case .noPresentingViewController:
            message = String(localized: "Internal error. Please try again later")
        }
    }
}
