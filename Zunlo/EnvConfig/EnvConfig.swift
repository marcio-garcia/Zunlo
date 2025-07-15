//
//  EnvConfig.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import Foundation

enum RuntimeEnvironment: String {
    case dev = "DEVELOPMENT"
    case prod = "PRODUCTION"
    case staging = "STAGING"
}

class EnvConfig {
    static let shared = EnvConfig()
    
    private init() {}
    
    var current: RuntimeEnvironment {
        let envString = Bundle.main.infoDictionary?["ENVIRONMENT"] as? String ?? "UNKNOWN"
        return RuntimeEnvironment(rawValue: envString) ?? .dev
    }
    
    var apiBaseUrl: String {
        let apiProtocol = Bundle.main.infoDictionary?["API_PROTOCOL"] as? String ?? ""
        let apiUrl =  Bundle.main.infoDictionary?["API_BASE_URL"] as? String ?? ""
        return "\(apiProtocol)://\(apiUrl)"
    }
    
    var apiFunctionsBaseUrl: String {
        let apiProtocol = Bundle.main.infoDictionary?["API_PROTOCOL"] as? String ?? ""
        let apiUrl =  Bundle.main.infoDictionary?["API_FUNCTIONS_BASE_URL"] as? String ?? ""
        return "\(apiProtocol)://\(apiUrl)"
    }
    
    var apiKey: String {
        Bundle.main.infoDictionary?["API_KEY"] as? String ?? ""
    }
}
