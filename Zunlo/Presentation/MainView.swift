//
//  MainView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import SwiftUI
import AdStack

struct MainView: View {
    @Namespace private var animationNamespace
    @State private var isShowingChat = false
    @State private var viewWidth: CGFloat = UIScreen.main.bounds.width
    
    @EnvironmentObject var upgradeFlowManager: UpgradeFlowManager
    @StateObject private var viewModel: MainViewModel
    
    private let factory: ViewFactory
    
    init(factory: ViewFactory) {
        self.factory = factory
        _viewModel = StateObject(wrappedValue: factory.makeMainViewModel())
    }
    
    var body: some View {
        ZStack {
            switch viewModel.state {
            case .loading:
                VStack {
                    ProgressView("Loading...")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .defaultBackground()
#if DEBUG
                .task {
                    await viewModel.generateDemoData()
                }
#endif
            case .empty, .loaded:
                GeometryReader { geo in
                    VStack{
                        ZStack {
                            TodayView(namespace: animationNamespace,
                                      showChat: $isShowingChat,
                                      appState: viewModel.appState)
                            .environmentObject(viewModel.appState.authManager!)
                            .environmentObject(upgradeFlowManager)
                            .opacity(isShowingChat ? 0.5 : 1.0)
                            .blur(radius: isShowingChat ? 1 : 0)
                            .allowsHitTesting(!isShowingChat)

                            ChatView(namespace: animationNamespace,
                                     showChat: $isShowingChat,
                                     factory: factory)
                            .offset(x: isShowingChat ? 0 : UIScreen.main.bounds.width)
                            .opacity(isShowingChat ? 1.0 : 0.0)
                        }
                        .animation(.spring(response: 0.6, dampingFraction: 0.90), value: isShowingChat)
                        
                        if !isShowingChat && !UIApplication.shared.isRunningUITests {
                            adBanner(containerWidth: geo.size.width)
                                .onChange(of: geo.size.width) { _, newWidth in viewWidth = newWidth }
                        }
                    }
                    .defaultBackground()
                }
                
            case .error(let message):
                VStack {
                    Text(message)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .defaultBackground()
            }
        }
        .task {
            await MainActor.run { viewModel.state = .loaded }
        }
    }
    
    private func adBanner(containerWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer()
            BannerAdView(
                adUnitID: BannerPlacement.home.adUnitID,
                size: .adaptive,
                containerWidth: containerWidth - 32,
                onEvent: { event in
                    switch event {
                    case .didReceiveAd:
                        print("✅ Ad received")
                    case .didFailToReceiveAd(let error):
                        print("❌ Failed to load ad: \(error)")
                    case .didClick:
                        print("👆 Ad clicked")
                    default:
                        break
                    }
                }
            )
            .frame(height: 50)
            .padding(.horizontal, 16)
        }
        .frame(height: 50)
    }
}
