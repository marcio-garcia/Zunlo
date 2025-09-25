//
//  DeepLink.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/4/25.
//

import Foundation

public enum DeepLink {
    case taskDetail(id: UUID)
    case editTask(id: UUID)
    case addTask
    case onboarding
    case magicLink(URL)
    case emailConfirmation(URL)
    case showSettings
}
