//
//  DeepLink.swift
//  FlowNavigator
//
//  Created by Marcio Garcia on 8/4/25.
//

import Foundation

enum DeepLink {
    case taskDetail(id: UUID)
    case editTask(id: UUID)
    case addTask
    case onboarding
    case login
    case showSettings
}
