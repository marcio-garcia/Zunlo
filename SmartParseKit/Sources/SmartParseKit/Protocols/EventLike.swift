//
//  EventLike.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 8/31/25.
//

import Foundation

/// Conform your app's Event model to this to use SmartParseKit directly.
public protocol EventLike {
    var id: UUID { get }
    var title: String { get }
    var startDate: Date { get }
    var endDate: Date? { get }
    var isRecurring: Bool { get }
}
