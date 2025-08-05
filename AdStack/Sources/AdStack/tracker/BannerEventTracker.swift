//
//  BannerEventTracker.swift
//  AdStack
//
//  Created by Marcio Garcia on 8/5/25.
//

import GoogleMobileAds

final class BannerEventTracker: NSObject, BannerViewDelegate {
    let onEvent: (BannerEvent) -> Void

    init(onEvent: @escaping (BannerEvent) -> Void) {
        self.onEvent = onEvent
    }

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        onEvent(.didReceiveAd)
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        onEvent(.didFailToReceiveAd(error))
    }

    func bannerViewDidRecordImpression(_ bannerView: BannerView) {
        onEvent(.didRecordImpression)
    }

    func bannerViewWillPresentScreen(_ bannerView: BannerView) {
        onEvent(.willPresentFullScreen)
    }

    func bannerViewWillDismissScreen(_ bannerView: BannerView) {
        onEvent(.willDismissFullScreen)
    }

    func bannerViewDidDismissScreen(_ bannerView: BannerView) {
        onEvent(.didDismissFullScreen)
    }

    func bannerViewDidRecordClick(_ bannerView: BannerView) {
        onEvent(.didClick)
    }
}
