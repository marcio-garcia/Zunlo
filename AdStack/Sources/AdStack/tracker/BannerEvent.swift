//
//  BannerEvent.swift
//  AdStack
//
//  Created by Marcio Garcia on 8/5/25.
//

public enum BannerEvent {
    case didReceiveAd
    case didFailToReceiveAd(Error)
    case didRecordImpression
    case didClick
    case willPresentFullScreen
    case willDismissFullScreen
    case didDismissFullScreen
}
