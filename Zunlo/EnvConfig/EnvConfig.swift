//
//  EnvConfig.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/22/25.
//

import Foundation
import AdStack

enum RuntimeEnvironment: String {
    case dev = "DEVELOPMENT"
    case prod = "PRODUCTION"
    case staging = "STAGING"
    
    func toAdEnvironment() -> AdEnvironmentType {
        switch self {
        case .dev: return AdEnvironmentType.dev
        case .prod: return AdEnvironmentType.prod
        case .staging: return AdEnvironmentType.staging
        }
    }
}

class EnvConfig: AdEnvironmentProvider {
    var environment: AdStack.AdEnvironmentType = .dev
    
    static let shared = EnvConfig()
    
    private init() {
        environment = current.toAdEnvironment()
    }
    
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
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
    
    let adMobBannerID: String = {
        Bundle.main.infoDictionary?["ADMOB_BANNER_ID"] as? String ?? ""
    }()

    let adMobInterstitialID: String = {
        Bundle.main.infoDictionary?["ADMOB_INTERSTITIAL_ID"] as? String ?? ""
    }()

    let adMobRewardedID: String = {
        Bundle.main.infoDictionary?["ADMOB_REWARDED_ID"] as? String ?? ""
    }()
    
    let googleOauthClientId: String = {
        Bundle.main.infoDictionary?["GOOGLE_OAUTH_CLIENT_ID"] as? String ?? ""
    }()
}
