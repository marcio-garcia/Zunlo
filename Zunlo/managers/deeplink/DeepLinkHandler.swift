//
//  DeepLinkHandler.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/4/25.
//

import Foundation
import FlowNavigator

class DeepLinkHandler: ObservableObject {
    let appState: AppState
    let nav: AppNav
    
    init(appState: AppState, nav: AppNav) {
        self.appState = appState
        self.nav = nav
    }
    
    @MainActor
    func handleDeepLink(_ deepLink: DeepLink) {
        switch deepLink {
        case .taskDetail(let id):
//            navigationManager.path = [.taskDetail(id)]
            break

        case .editTask(let id):
            Task {
                guard let task = try? await appState.userTaskRepository?.fetchTask(id: id) else {
                    return
                }
                nav.showSheet(.editTask(task), for: UUID())
            }

        case .addTask:
            nav.showSheet(.addTask, for: UUID())

        case .onboarding:
            nav.showFullScreen(.onboarding, for: UUID())

        case .magicLink(let url):
            NotificationCenter.default.post(name: .authDeepLink, object: url)

        case .showSettings:
            nav.showSheet(.settings, for: UUID())
        }
    }
}
