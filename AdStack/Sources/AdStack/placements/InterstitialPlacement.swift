//
//  InterstitialPlacement.swift
//  AdStack
//
//  Created by Marcio Garcia on 8/5/25.
//

public enum InterstitialPlacement {
    case openCalendar
    case openTaskInbox

    public var adUnitID: String {
        switch AdEnvironment.current {
        case .dev:
            return "ca-app-pub-3940256099942544/4411468910" // test
        case .staging:
            switch self {
            case .openCalendar: return "ca-app-pub-xxxxxxxxxxxxxxxx/onboarding_interstitial_stg"
            case .openTaskInbox: return "ca-app-pub-xxxxxxxxxxxxxxxx/gameover_interstitial_stg"
            }
        case .prod:
            switch self {
            case .openCalendar: return "ca-app-pub-xxxxxxxxxxxxxxxx/onboarding_interstitial_prod"
            case .openTaskInbox: return "ca-app-pub-xxxxxxxxxxxxxxxx/gameover_interstitial_prod"
            }
        }
    }
}
