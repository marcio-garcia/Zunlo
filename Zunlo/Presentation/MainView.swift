//
//  MainView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import SwiftUI

struct MainView: View {
    @Namespace private var chatNamespace
    @State private var isShowingChat = false
    @StateObject private var viewModel: MainViewModel
    
    private let factory: ViewFactory
    
    init(factory: ViewFactory) {
        self.factory = factory
        _viewModel = StateObject(wrappedValue: factory.makeMainViewModel())
    }
    
    var body: some View {
        ZStack {
//            CalendarScheduleView(repository: viewModel.eventRepository)
            TodayView(eventRepository: viewModel.eventRepository,
                      taskRepository: viewModel.userTaskRepository)

            if !isShowingChat {
                FloatingSearchBar(namespace: chatNamespace) {
                    withAnimation(.spring()) {
                        isShowingChat = true
                    }
                }
            }

            if isShowingChat {
                ChatScreenView(namespace: chatNamespace,
                               isPresented: $isShowingChat,
                               factory: factory)
            }
        }
    }
}
