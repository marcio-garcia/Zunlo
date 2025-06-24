//
//  EnvConfig.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import Foundation

class EnvConfig {
    static let shared = EnvConfig()
    
    private init() {}
    
    var current: String {
        Bundle.main.infoDictionary?["ENVIRONMENT"] as? String ?? "UNKNOWN"
    }
    
    var apiBaseUrl: String {
        let apiProtocol = Bundle.main.infoDictionary?["API_PROTOCOL"] as? String ?? ""
        let apiUrl =  Bundle.main.infoDictionary?["API_BASE_URL"] as? String ?? ""
        return "\(apiProtocol)://\(apiUrl)"
    }
    
    var apiKey: String {
        Bundle.main.infoDictionary?["API_KEY"] as? String ?? ""
    }
}
