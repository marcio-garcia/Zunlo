//
//  MainView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import SwiftUI

struct MainView: View {
    @Namespace private var animationNamespace
    @State private var isShowingChat = false
    @StateObject private var viewModel: MainViewModel
    
    private let factory: ViewFactory
    
    init(factory: ViewFactory) {
        self.factory = factory
        _viewModel = StateObject(wrappedValue: factory.makeMainViewModel())
    }
    
    var body: some View {
        ZStack {
            if isShowingChat {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .blur(radius: 10)
                    .animation(.easeInOut(duration: 0.3), value: isShowingChat)
                ChatScreenView(namespace: animationNamespace,
                               showChat: $isShowingChat,
                               factory: factory)
            } else {
                TodayView(namespace: animationNamespace,
                          showChat: $isShowingChat,
                          eventRepository: viewModel.eventRepository,
                          taskRepository: viewModel.userTaskRepository,
                          locationManager: viewModel.locationManager,
                          pushService: viewModel.pushService)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.90), value: isShowingChat)
    }
}
