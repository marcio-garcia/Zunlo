//
//  BannerPlacement.swift
//  AdStack
//
//  Created by Marcio Garcia on 8/5/25.
//

public enum BannerPlacement {
    case home
    case taskInbox
    case eventCalendar
    case settings
    case chat

    public var adUnitID: String {
        switch AdEnvironment.current {
        case .dev: return testID
        case .staging: return stagingID
        case .prod: return productionID
        }
    }

    private var testID: String {
        "ca-app-pub-3940256099942544/2934735716"
    }

    private var stagingID: String {
        switch self {
        case .home: return "ca-app-pub-xxxxxxxxxxxxxxxx/home_banner_stg"
        case .taskInbox: return "ca-app-pub-xxxxxxxxxxxxxxxx/tasklist_banner_stg"
        case .eventCalendar: return "ca-app-pub-xxxxxxxxxxxxxxxx/tasklist_banner_stg"
        case .settings: return "ca-app-pub-xxxxxxxxxxxxxxxx/settings_banner_stg"
        case .chat: return "ca-app-pub-xxxxxxxxxxxxxxxx/tasklist_banner_stg"
        }
    }

    private var productionID: String {
        switch self {
        case .home: return "ca-app-pub-xxxxxxxxxxxxxxxx/home_banner_prod"
        case .taskInbox: return "ca-app-pub-xxxxxxxxxxxxxxxx/tasklist_banner_prod"
        case .eventCalendar: return "ca-app-pub-xxxxxxxxxxxxxxxx/tasklist_banner_prod"
        case .settings: return "ca-app-pub-xxxxxxxxxxxxxxxx/settings_banner_prod"
        case .chat: return "ca-app-pub-xxxxxxxxxxxxxxxx/tasklist_banner_prod"
        }
    }
}
