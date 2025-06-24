//
//  Auth.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/24/25.
//

struct Auth {
    let accessToken: String
    let user: User
}

extension Auth {
    static var empty: Auth {
        return Auth(accessToken: "", user: User(id: "", email: ""))
    }
}
