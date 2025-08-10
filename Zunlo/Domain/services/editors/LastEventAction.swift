//
//  LastEventAction.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/10/25.
//

import Foundation

enum LastEventAction {
    case none
    case insert
    case update
    case delete
    case fetch([EventOccurrence])
    case error(Error)
}
