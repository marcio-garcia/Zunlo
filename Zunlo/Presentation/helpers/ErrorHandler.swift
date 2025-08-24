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
        }
    }

    func clear() {
        message = nil
    }
}
