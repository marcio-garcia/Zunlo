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

    // Track ad loading states
    @Published public private(set) var isInterstitialLoading = false
    @Published public private(set) var isRewardedLoading = false
    @Published public private(set) var isInterstitialReady = false
    @Published public private(set) var isRewardedReady = false
    @Published public private(set) var lastInterstitialError: String?
    @Published public private(set) var lastRewardedError: String?

    private var isInitialized = false
    private let maxRetryAttempts = 3
    private var interstitialRetryCount = 0
    private var rewardedRetryCount = 0

    // Rate limiting
    private var lastInterstitialLoadTime: Date?
    private var lastRewardedLoadTime: Date?
    private let minTimeBetweenLoads: TimeInterval = 30 // 30 seconds minimum between loads
    private let cooldownPeriod: TimeInterval = 300 // 5 minutes cooldown after max retries
    
    public init() {
        Task {
            await initialize()
        }
    }

    // MARK: - Initialization

    private func initialize() async {
        let status = await MobileAds.shared.start()
        print("✅ AdMob initialized successfully")
        isInitialized = true
    }

    private func ensureInitialized() async -> Bool {
        if !isInitialized {
            await initialize()
        }
        return isInitialized
    }

    // MARK: - Interstitial

    public func loadInterstitial(for placement: InterstitialPlacement) async {
        guard await ensureInitialized() else {
            await MainActor.run {
                lastInterstitialError = "AdMob not initialized"
                isInterstitialReady = false
                isInterstitialLoading = false
            }
            return
        }

        // Rate limiting check
        let now = Date()
        if let lastLoadTime = lastInterstitialLoadTime {
            let timeSinceLastLoad = now.timeIntervalSince(lastLoadTime)
            if timeSinceLastLoad < minTimeBetweenLoads {
                let waitTime = minTimeBetweenLoads - timeSinceLastLoad
                await MainActor.run {
                    lastInterstitialError = "Rate limited: wait \(Int(waitTime))s before next load"
                    isInterstitialLoading = false
                }
                return
            }
        }

        // Check cooldown period after max retries
        if interstitialRetryCount >= maxRetryAttempts {
            if let lastLoadTime = lastInterstitialLoadTime {
                let timeSinceCooldown = now.timeIntervalSince(lastLoadTime)
                if timeSinceCooldown < cooldownPeriod {
                    let remainingCooldown = cooldownPeriod - timeSinceCooldown
                    await MainActor.run {
                        lastInterstitialError = "Cooldown active: wait \(Int(remainingCooldown / 60))m \(Int(remainingCooldown.truncatingRemainder(dividingBy: 60)))s"
                        isInterstitialLoading = false
                    }
                    return
                } else {
                    // Reset retry count after cooldown
                    interstitialRetryCount = 0
                }
            }
        }

        lastInterstitialLoadTime = now
        await MainActor.run {
            isInterstitialLoading = true
            lastInterstitialError = nil
        }

        do {
            interstitialAd = try await InterstitialAd.load(
                with: placement.adUnitID,
                request: Request()
            )
            interstitialRetryCount = 0
            await MainActor.run {
                isInterstitialReady = true
                isInterstitialLoading = false
                lastInterstitialError = nil
            }
            print("✅ Interstitial ad loaded for \(placement)")
        } catch {
            let errorMessage = "Failed to load interstitial for \(placement): \(error.localizedDescription)"
            print("❌ \(errorMessage)")

            interstitialAd = nil
            interstitialRetryCount += 1

            await MainActor.run {
                isInterstitialReady = false
                isInterstitialLoading = false
                lastInterstitialError = errorMessage
            }

            if interstitialRetryCount < maxRetryAttempts {
                print("🔄 Retrying interstitial load (attempt \(interstitialRetryCount + 1)/\(maxRetryAttempts))")
                try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(interstitialRetryCount)) * 1_000_000_000))
                await loadInterstitial(for: placement)
            }
        }
    }

    @MainActor
    public func showInterstitial(
        from viewController: UIViewController,
        onEvent: ((FullScreenAdEvent) -> Void)? = nil
    ) {
        guard isInterstitialReady, let ad = interstitialAd else {
            let message = lastInterstitialError ?? "Interstitial not ready"
            print("⚠️ \(message)")
            let error = NSError(domain: "AdMobManager", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
            onEvent?(.didFailToPresent(error))
            return
        }

        let tracker = FullScreenAdEventTracker { [weak self] event in
            onEvent?(event)
            if case .didDismiss = event {
                Task { @MainActor in
                    self?.interstitialRetryCount = 0
                }
            }
        }

        ad.fullScreenContentDelegate = tracker
        interstitialEventTracker = tracker

        ad.present(from: viewController)
        interstitialAd = nil
        isInterstitialReady = false
        print("✅ Interstitial ad presented successfully")
    }

    // MARK: - Rewarded

    public func loadRewarded(for placement: RewardedPlacement) async {
        guard await ensureInitialized() else {
            await MainActor.run {
                lastRewardedError = "AdMob not initialized"
                isRewardedReady = false
                isRewardedLoading = false
            }
            return
        }

        // Rate limiting check
        let now = Date()
        if let lastLoadTime = lastRewardedLoadTime {
            let timeSinceLastLoad = now.timeIntervalSince(lastLoadTime)
            if timeSinceLastLoad < minTimeBetweenLoads {
                let waitTime = minTimeBetweenLoads - timeSinceLastLoad
                await MainActor.run {
                    lastRewardedError = "Rate limited: wait \(Int(waitTime))s before next load"
                    isRewardedLoading = false
                }
                return
            }
        }

        // Check cooldown period after max retries
        if rewardedRetryCount >= maxRetryAttempts {
            if let lastLoadTime = lastRewardedLoadTime {
                let timeSinceCooldown = now.timeIntervalSince(lastLoadTime)
                if timeSinceCooldown < cooldownPeriod {
                    let remainingCooldown = cooldownPeriod - timeSinceCooldown
                    await MainActor.run {
                        lastRewardedError = "Cooldown active: wait \(Int(remainingCooldown / 60))m \(Int(remainingCooldown.truncatingRemainder(dividingBy: 60)))s"
                        isRewardedLoading = false
                    }
                    return
                } else {
                    // Reset retry count after cooldown
                    rewardedRetryCount = 0
                }
            }
        }

        lastRewardedLoadTime = now
        await MainActor.run {
            isRewardedLoading = true
            lastRewardedError = nil
        }

        do {
            rewardedAd = try await RewardedAd.load(
                with: placement.adUnitID,
                request: Request()
            )
            rewardedRetryCount = 0
            await MainActor.run {
                isRewardedReady = true
                isRewardedLoading = false
                lastRewardedError = nil
            }
            print("✅ Rewarded ad loaded for \(placement)")
        } catch {
            let errorMessage = "Failed to load rewarded for \(placement): \(error.localizedDescription)"
            print("❌ \(errorMessage)")

            rewardedAd = nil
            rewardedRetryCount += 1

            await MainActor.run {
                isRewardedReady = false
                isRewardedLoading = false
                lastRewardedError = errorMessage
            }

            if rewardedRetryCount < maxRetryAttempts {
                print("🔄 Retrying rewarded load (attempt \(rewardedRetryCount + 1)/\(maxRetryAttempts))")
                try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(rewardedRetryCount)) * 1_000_000_000))
                await loadRewarded(for: placement)
            }
        }
    }
    
    @MainActor
    public func showRewarded(
        from viewController: UIViewController,
        onEvent: ((FullScreenAdEvent) -> Void)? = nil,
        onRewardEarned: ((Double, String) -> Void)? = nil
    ) {
        guard isRewardedReady, let ad = rewardedAd else {
            let message = lastRewardedError ?? "Rewarded ad not ready"
            print("⚠️ \(message)")
            let error = NSError(domain: "AdMobManager", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
            onEvent?(.didFailToPresent(error))
            return
        }

        let tracker = FullScreenAdEventTracker { [weak self] event in
            onEvent?(event)
            if case .didDismiss = event {
                Task { @MainActor in
                    self?.rewardedRetryCount = 0
                }
            }
        }

        ad.fullScreenContentDelegate = tracker
        rewardedEventTracker = tracker

        ad.present(from: viewController) {
            let reward = ad.adReward
            print("🎉 User earned reward: \(reward.amount) \(reward.type)")
            onRewardEarned?(reward.amount.doubleValue, reward.type)
        }

        rewardedAd = nil
        isRewardedReady = false
        print("✅ Rewarded ad presented successfully")
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
            showInterstitial(from: viewController, onEvent: onEvent)
        case .rewarded:
            showRewarded(from: viewController, onEvent: onEvent, onRewardEarned: onRewardEarned)
        }
    }

    // MARK: - Utility Methods

    @MainActor
    public func clearErrors() {
        lastInterstitialError = nil
        lastRewardedError = nil
    }

    @MainActor
    public func resetRetryCounters() {
        interstitialRetryCount = 0
        rewardedRetryCount = 0
    }

    public func canLoadAd(type: AdType) -> Bool {
        let now = Date()

        switch type {
        case .interstitial:
            if isInterstitialLoading { return false }

            // Check rate limiting
            if let lastLoadTime = lastInterstitialLoadTime {
                let timeSinceLastLoad = now.timeIntervalSince(lastLoadTime)
                if timeSinceLastLoad < minTimeBetweenLoads { return false }
            }

            // Check cooldown after max retries
            if interstitialRetryCount >= maxRetryAttempts {
                if let lastLoadTime = lastInterstitialLoadTime {
                    let timeSinceCooldown = now.timeIntervalSince(lastLoadTime)
                    return timeSinceCooldown >= cooldownPeriod
                }
                return false
            }

            return true

        case .rewarded:
            if isRewardedLoading { return false }

            // Check rate limiting
            if let lastLoadTime = lastRewardedLoadTime {
                let timeSinceLastLoad = now.timeIntervalSince(lastLoadTime)
                if timeSinceLastLoad < minTimeBetweenLoads { return false }
            }

            // Check cooldown after max retries
            if rewardedRetryCount >= maxRetryAttempts {
                if let lastLoadTime = lastRewardedLoadTime {
                    let timeSinceCooldown = now.timeIntervalSince(lastLoadTime)
                    return timeSinceCooldown >= cooldownPeriod
                }
                return false
            }

            return true
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
