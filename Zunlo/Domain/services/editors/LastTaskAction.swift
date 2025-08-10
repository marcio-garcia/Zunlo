//
//  LastTaskAction.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/10/25.
//

import Foundation

enum LastTaskAction {
    case none
    case insert
    case update
    case delete
    case fetch([UserTask])
    case fetchTags([String])
    case error(Error)
}
