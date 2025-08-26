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
        } else if (error as NSError).domain == "io.realm" {
            message = error.localizedDescription
        } else {
            print("Execution error: \(error)")
            message = error.localizedDescription
        }
    }

    func clear() {
        message = nil
    }
}
