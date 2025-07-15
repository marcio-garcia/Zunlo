//
//  PushTokensRemote.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/15/25.
//

import Foundation

struct PushTokenRemote: Codable {
    var id: String?
    let user_id: String
    let token: String
    let platform: String
    let app_version: String?
}
