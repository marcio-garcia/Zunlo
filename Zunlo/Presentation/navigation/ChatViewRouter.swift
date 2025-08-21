//
//  ChatViewRouter.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/21/25.
//

import SwiftUI
import FlowNavigator

@MainActor
enum ChatViewRouter {
    
//    static func sheetView(
//        for route: SheetRoute,
//        navigationManager nav: AppNav,
//        factory: TaskViews
//    ) -> some View {
//        switch route {
//        case .addTask:
//            return factory.buildAddTaskView()
//
//        case .editTask(let id):
//            return factory.buildEditTaskView(id: id)
//
//        default:
//            return AnyView(FallbackView(message: "No view found for this task sheet route.", nav: nav, viewID: UUID()))
//        }
//    }

    static func dialogView(
        for route: DialogRoute,
        navigationManager nav: AppNav,
        factory: ChatViews
    ) -> some View {
        switch route {
        case .deleteChatMessage(let id):
            return factory.buildDeleteMsgView(msgId: id)
        case .deleteAllChat:
            return factory.buildDeleteAllView()
        default:
            return AnyView(FallbackView(message: "No dialog found for this route.", nav: nav, viewID: UUID()))
        }
    }

//    static func navigationDestination(
//        for route: StackRoute,
//        navigationManager nav: AppNav,
//        factory: TaskViews
//    ) -> some View {
//        switch route {
//        case .taskInbox:
//            return factory.buildTaskInboxView()
//
//        case .taskDetail(let id):
//            return factory.buildTaskDetailView(id: id)
//
//        default:
//            return AnyView(FallbackView(message: "No view found for this stack route.", nav: nav, viewID: UUID()))
//        }
//    }
}
