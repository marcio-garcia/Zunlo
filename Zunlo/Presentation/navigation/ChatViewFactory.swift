//
//  ChatViewFactory.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/21/25.
//

import SwiftUI
import FlowNavigator

public protocol ChatViews {
    func buildDeleteAllView() -> AnyView
    func buildDeleteMsgView(msgId: UUID) -> AnyView
}

struct ChatViewFactory: ChatViews {
    let viewID: UUID
    let nav: AppNav
    let onOptionSelected: ((String, UUID?) -> Void)?
    
    internal init(
        viewID: UUID,
        nav: AppNav,
        onOptionSelected: ((String, UUID?) -> Void)? = nil
    ) {
        self.viewID = viewID
        self.nav = nav
        self.onOptionSelected = onOptionSelected
    }

    func buildDeleteAllView() -> AnyView {
        return AnyView(
            Group {
                Button("Delete all messages", role: .destructive) {
                    onOptionSelected?("deleteAll", nil)
                }
                Button("Cancel", role: .cancel) {
                    onOptionSelected?("cancel", nil)
                }
            }
        )
    }
    
    func buildDeleteMsgView(msgId: UUID) -> AnyView {
        return AnyView(
            Group {
                Button("Delete message", role: .destructive) {
                    onOptionSelected?("delete", msgId)
                }
                Button("Cancel", role: .cancel) {
                    onOptionSelected?("cancel", nil)
                }
            }
        )
    }
}
