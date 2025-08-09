//
//  TaskViews.swift
//  FlowNavigator
//
//  Created by Marcio Garcia on 8/7/25.
//

import SwiftUI

public protocol TaskViews {
    func buildTaskInboxView() -> AnyView
    func buildAddTaskView() -> AnyView
    func buildEditTaskView(id: UUID) -> AnyView
    func buildTaskDetailView(id: UUID) -> AnyView
    func buildDeleteTaskConfirmationView(onOptionSelected: @escaping (String) -> Void) -> AnyView
}
