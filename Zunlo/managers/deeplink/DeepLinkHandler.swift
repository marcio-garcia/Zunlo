//
//  DeepLinkHandler.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/4/25.
//

import Foundation
import FlowNavigator

class DeepLinkHandler: ObservableObject {
    let navigationManager: AppNavigationManager
    
    init(navigationManager: AppNavigationManager) {
        self.navigationManager = navigationManager
    }
    
    @MainActor
    func handleDeepLink(_ deepLink: DeepLink) {
        switch deepLink {
        case .taskDetail(let id):
//            navigationManager.path = [.taskDetail(id)]
            break

        case .editTask(let id):
            navigationManager.showSheet(.editTask(id), for: UUID())

        case .addTask:
            navigationManager.showSheet(.addTask, for: UUID())

        case .onboarding:
            navigationManager.showFullScreen(.onboarding, for: UUID())

        case .magicLink(let url):
            NotificationCenter.default.post(name: .authDeepLink, object: url)

        case .showSettings:
            navigationManager.showSheet(.settings, for: UUID())
        }
    }
}
