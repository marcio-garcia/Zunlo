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
            navigationManager.path = [.taskDetail(id)]

        case .editTask(let id):
            navigationManager.showSheet(.editTask(id))

        case .addTask:
            navigationManager.showSheet(.addTask)

        case .onboarding:
            navigationManager.showFullScreen(.onboarding)

        case .magicLink(let url):
            NotificationCenter.default.post(name: .authDeepLink, object: url)

        case .showSettings:
            navigationManager.showSheet(.settings)
        }
    }
}
