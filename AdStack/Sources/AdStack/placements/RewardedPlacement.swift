//
//  RewardedPlacement.swift
//  AdStack
//
//  Created by Marcio Garcia on 8/5/25.
//

public enum RewardedPlacement {
    case chat

    public var adUnitID: String {
        switch AdEnvironment.current {
        case .dev:
            return "ca-app-pub-3940256099942544/1712485313" // test
        case .staging:
            switch self {
            case .chat: return "ca-app-pub-xxxxxxxxxxxxxxxx/unlockfeature_rewarded_stg"
            }
        case .prod:
            switch self {
            case .chat: return "ca-app-pub-xxxxxxxxxxxxxxxx/unlockfeature_rewarded_prod"
            }
        }
    }
}
