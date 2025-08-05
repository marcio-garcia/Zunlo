//
//  AdMobManager.swift
//  AdStack
//
//  Created by Marcio Garcia on 8/5/25.
//

import Foundation
import GoogleMobileAds
import UIKit

public final class AdMobManager: ObservableObject {
    private var interstitialAd: InterstitialAd?
    private var rewardedAd: RewardedAd?

    private var interstitialEventTracker: FullScreenAdEventTracker?
    private var rewardedEventTracker: FullScreenAdEventTracker?
    
    public init() {
        Task {
            await initialize()
        }
    }

    // MARK: - Initialization

    private func initialize() async {
        await MobileAds.shared.start()
//        await loadInterstitial()
//        await loadRewarded()
    }

    // MARK: - Interstitial

    public func loadInterstitial(for placement: InterstitialPlacement) async {
        do {
            interstitialAd = try await InterstitialAd.load(
                with: placement.adUnitID,
                request: Request()
            )
        } catch {
            print("❌ Failed to load interstitial for \(placement): \(error)")
            interstitialAd = nil
        }
    }

    @MainActor
    public func showInterstitial(
        from viewController: UIViewController,
        onEvent: ((FullScreenAdEvent) -> Void)? = nil
    ) {
        guard let ad = interstitialAd else {
            print("⚠️ Interstitial not ready")
            onEvent?(.didDismiss) // still notify to resume app flow
            return
        }

        let tracker = FullScreenAdEventTracker { event in
            onEvent?(event)
        }

        ad.fullScreenContentDelegate = tracker
        interstitialEventTracker = tracker

        ad.present(from: viewController)
        interstitialAd = nil
    }

    // MARK: - Rewarded

    public func loadRewarded(for placement: RewardedPlacement) async {
        do {
            rewardedAd = try await RewardedAd.load(
                with: placement.adUnitID,
                request: Request()
            )
        } catch {
            print("❌ Failed to load rewarded: \(error.localizedDescription)")
            rewardedAd = nil
        }
    }
    
    @MainActor
    public func showRewarded(
        from viewController: UIViewController,
        onEvent: ((FullScreenAdEvent) -> Void)? = nil,
        onRewardEarned: ((Double, String) -> Void)? = nil
    ) {
        guard let ad = rewardedAd else {
            print("⚠️ Rewarded ad not ready")
            onEvent?(.didDismiss) // so app flow still resumes
            return
        }

        let tracker = FullScreenAdEventTracker { event in
            onEvent?(event)
        }

        ad.fullScreenContentDelegate = tracker
        rewardedEventTracker = tracker

        ad.present(from: viewController) {
            let reward = ad.adReward
            print("🎉 User earned reward: \(reward.amount) \(reward.type)")
            onRewardEarned?(reward.amount.doubleValue, reward.type)
        }
        
        rewardedAd = nil
    }

    @MainActor
    public func showAd(
        _ type: AdType,
        from viewController: UIViewController,
        onEvent: ((FullScreenAdEvent) -> Void)? = nil,
        onRewardEarned: ((Double, String) -> Void)? = nil
    ) {
        switch type {
        case .interstitial:
            guard let ad = interstitialAd else {
                print("⚠️ Interstitial not ready")
                onEvent?(.didDismiss)
                return
            }

            let tracker = FullScreenAdEventTracker { event in
                onEvent?(event)
            }

            ad.fullScreenContentDelegate = tracker
            interstitialEventTracker = tracker

            ad.present(from: viewController)
            interstitialAd = nil

        case .rewarded:
            guard let ad = rewardedAd else {
                print("⚠️ Rewarded ad not ready")
                onEvent?(.didDismiss)
                return
            }

            let tracker = FullScreenAdEventTracker { event in
                onEvent?(event)
            }

            ad.fullScreenContentDelegate = tracker
            rewardedEventTracker = tracker

            ad.present(from: viewController) {
                let reward = ad.adReward
                print("🎉 User earned reward: \(reward.amount) \(reward.type)")
                onRewardEarned?(reward.amount.doubleValue, reward.type)
            }
            
            rewardedAd = nil
        }
    }

}

private final class InterstitialDelegate: NSObject, FullScreenContentDelegate {
    let onDismiss: () -> Void

    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        onDismiss()
    }

    func adDidFailToPresentFullScreenContent(_ ad: any FullScreenPresentingAd, withError error: Error) {
        print("❌ Failed to present ad: \(error.localizedDescription)")
        onDismiss()
    }
}
