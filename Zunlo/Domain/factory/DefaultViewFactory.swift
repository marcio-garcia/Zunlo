//
//  DefaultViewFactory.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import Foundation

protocol ViewFactory {
    func makeMainViewModel() -> MainViewModel
    func makeChatScreenViewModel() -> ChatScreenViewModel
}

final class DefaultViewFactory: ViewFactory {
    let appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
    }

    func makeMainViewModel() -> MainViewModel {
        let userId = UUID(uuidString: appState.authManager.auth?.user.id ?? "")
        let chatVM = ChatScreenViewModel(repository: DefaultChatRepository(store: RealmChatLocalStore(),
                                                                           userId: userId))
        return MainViewModel(eventRepository: appState.eventRepository,
                             userTaskRepository: appState.userTaskRepository,
                             chatViewModel: chatVM)
    }
    
    func makeChatScreenViewModel() -> ChatScreenViewModel {
        return ChatScreenViewModel(repository: appState.chatRepository)
    }
}
