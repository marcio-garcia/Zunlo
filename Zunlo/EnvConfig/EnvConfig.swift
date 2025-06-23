//
//  EnvConfig.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import Foundation

enum EnvConfig {
    static var current: String {
        Bundle.main.infoDictionary?["ENVIRONMENT"] as? String ?? "UNKNOWN"
    }
    static var apiBaseUrl: String {
        Bundle.main.infoDictionary?["API_BASE_URL"] as? String ?? ""
    }
}
