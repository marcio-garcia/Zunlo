//
//  ToolExecutionState.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/16/25.
//

import Foundation

enum ToolRoute: Equatable {
    case taskDetail(id: UUID)
    case eventDetail(id: UUID)
    case url(URL)
}

enum ToolOutcome: Equatable {
    case success(payload: AnyHashable)             // swap for your domain type
    case navigate(ToolRoute)
    case toast(String, duration: TimeInterval = 5)
}

enum ToolKind: Hashable {
    case aiTool(name: String)
}

struct ToolExecutionState: Equatable {
    var kind: ToolKind
    var isRunning: Bool = true
    var progress: Double? = nil     // 0...1
    var status: String? = nil
    var error: String? = nil
    var startedAt: Date = .init()
    var finishedAt: Date? = nil
}

struct ToolOutcomeEvent: Identifiable, Equatable {
    let id = UUID()
    let runID: UUID
    let outcome: ToolOutcome
    let createdAt: Date = .init()
}
