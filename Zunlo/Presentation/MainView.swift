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
        GeometryReader { geo in
            VStack{
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .blur(radius: 10)
                    
                    TodayView(namespace: animationNamespace,
                              showChat: $isShowingChat,
                              appState: viewModel.appState)
                    .environmentObject(viewModel.appState.authManager!)
                    .environmentObject(upgradeFlowManager)
                    
                    if isShowingChat {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .transition(.opacity)
                            .blur(radius: 10)
                        
                        ChatScreenView(namespace: animationNamespace,
                                       showChat: $isShowingChat,
                                       factory: factory)
                    }
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.90), value: isShowingChat)
                
                VStack(spacing: 0) {
                    Spacer()
                    BannerAdView(
                        adUnitID: BannerPlacement.home.adUnitID,
                        size: .adaptive,
                        containerWidth: geo.size.width - 32,
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
                .onChange(of: geo.size.width) { _, newWidth in viewWidth = newWidth }
            }
            .defaultBackground()
        }
    }
}
