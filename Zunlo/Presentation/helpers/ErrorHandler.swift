//
//  ErrorHandler.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/19/25.
//

import Foundation

@MainActor
class ErrorHandler: ObservableObject {
    @Published var message: String?

    func handle(_ error: Error) {
        message = SupabaseErrorFormatter.format(error)
    }

    func clear() {
        message = nil
    }
}
