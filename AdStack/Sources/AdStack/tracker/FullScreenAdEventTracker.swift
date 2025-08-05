//
//  FullScreenAdEventTracker.swift
//  AdStack
//
//  Created by Marcio Garcia on 8/5/25.
//

import GoogleMobileAds

final class FullScreenAdEventTracker: NSObject, FullScreenContentDelegate {
    let onEvent: (FullScreenAdEvent) -> Void

    init(onEvent: @escaping (FullScreenAdEvent) -> Void) {
        self.onEvent = onEvent
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        onEvent(.didDismiss)
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        onEvent(.didFailToPresent(error))
    }

    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        onEvent(.didRecordImpression)
    }

    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        onEvent(.didClick)
    }
}
