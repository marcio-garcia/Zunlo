//
//  AuthSignInRequest.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/24/25.
//

import UIKit

enum AuthSignInMethod {
    case emailPassword(email: String, password: String)
    case magicLink(email: String)
    case google(viewController: UIViewController)
    case anonymous
}

struct AuthSignInRequest {
    let method: AuthSignInMethod
    let redirectTo: URL?

    init(method: AuthSignInMethod, redirectTo: URL? = nil) {
        self.method = method
        self.redirectTo = redirectTo
    }
}

// Convenience initializers
extension AuthSignInRequest {
    static func emailPassword(email: String, password: String) -> AuthSignInRequest {
        AuthSignInRequest(method: .emailPassword(email: email, password: password))
    }

    static func magicLink(email: String, redirectTo: URL? = nil) -> AuthSignInRequest {
        AuthSignInRequest(method: .magicLink(email: email), redirectTo: redirectTo)
    }

    static func google(viewController: UIViewController) -> AuthSignInRequest {
        AuthSignInRequest(method: .google(viewController: viewController))
    }

    static var anonymous: AuthSignInRequest {
        AuthSignInRequest(method: .anonymous)
    }
}