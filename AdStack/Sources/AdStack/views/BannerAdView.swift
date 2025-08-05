//
//  BannerAdView.swift
//  AdStack
//
//  Created by Marcio Garcia on 8/5/25.
//

import SwiftUI
import GoogleMobileAds

public struct BannerAdView: UIViewRepresentable {
    public enum BannerSize {
        case fixed(CGSize)
        case adaptive
    }

    private let adUnitID: String
    private let size: BannerSize
    private let containerWidth: CGFloat
    private var onEvent: ((BannerEvent) -> Void)? = nil
    
    public init(
        adUnitID: String,
        size: BannerSize = .adaptive,
        containerWidth: CGFloat,
        onEvent: ((BannerEvent) -> Void)? = nil
    ) {
        self.adUnitID = adUnitID
        self.size = size
        self.containerWidth = containerWidth
        self.onEvent = onEvent
    }

    public func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear

        let banner = createBannerView()
        container.addSubview(banner)

        // Center banner horizontally in container
        banner.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            banner.topAnchor.constraint(equalTo: container.topAnchor),
            banner.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        context.coordinator.bannerView = banner
        context.coordinator.containerView = container

        let tracker = onEvent.map { BannerEventTracker(onEvent: $0) }
        banner.delegate = tracker
        context.coordinator.tracker = tracker
        
        return container
    }

    public func updateUIView(_ uiView: UIView, context: Context) {
        let currentBanner = context.coordinator.bannerView
        let currentSize = currentBanner?.adSize ?? AdSizeInvalid

        let newSize: AdSize
        switch size {
        case .fixed(let fixedSize):
            newSize = adSizeFor(cgSize: fixedSize)
        case .adaptive:
            newSize = currentOrientationAnchoredAdaptiveBanner(width: containerWidth)
        }

        // If size changed, remove old and insert new
        if !isAdSizeEqualToSize(size1: currentSize, size2: newSize) {
            currentBanner?.removeFromSuperview()

            let newBanner = createBannerView()
            context.coordinator.bannerView = newBanner
            
            let tracker = onEvent.map { BannerEventTracker(onEvent: $0) }
            currentBanner?.delegate = tracker
            context.coordinator.tracker = tracker
            
            uiView.addSubview(newBanner)

            newBanner.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                newBanner.centerXAnchor.constraint(equalTo: uiView.centerXAnchor),
                newBanner.topAnchor.constraint(equalTo: uiView.topAnchor),
                newBanner.bottomAnchor.constraint(equalTo: uiView.bottomAnchor)
            ])
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func createBannerView() -> BannerView {
        let adSize: AdSize
        switch size {
        case .fixed(let fixedSize):
            adSize = adSizeFor(cgSize: fixedSize)
        case .adaptive:
            adSize = currentOrientationAnchoredAdaptiveBanner(width: containerWidth)
        }

        let banner = BannerView(adSize: adSize)
        banner.adUnitID = adUnitID
        banner.rootViewController = getRootViewController()
        banner.delegate = onEvent.map { BannerEventTracker(onEvent: $0) }
        banner.load(Request())
        return banner
    }

    public class Coordinator {
        var bannerView: BannerView?
        var containerView: UIView?
        var tracker: BannerEventTracker?
    }
    
    private func getRootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.rootViewController
    }
}
