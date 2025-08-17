//
//  Toast.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/16/25.
//

import Foundation

public struct Toast: Identifiable, Equatable {
    public let id = UUID()
    public var message: String
    public var duration: TimeInterval = 5 // seconds
    
    public init(_ message: String, duration: TimeInterval = 5) {
        self.message = message
        self.duration = duration
    }
}

public enum ToastPosition { case top, bottom }
