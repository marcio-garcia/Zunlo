//
//  FallbackView.swift
//  FlowNavigator
//
//  Created by Marcio Garcia on 8/4/25.
//

import SwiftUI

public struct FallbackView<
    SheetRoute: AppSheetRoute,
    FullScreenRoute: AppFullScreenRoute,
    DialogRoute: AppDialogRoute,
    StackRoute: AppStackRoute
>: View {
    let message: String
    let nav: AppNavigationManager<SheetRoute, FullScreenRoute, DialogRoute, StackRoute>
    let viewID: UUID

    public init(
        message: String,
        nav: AppNavigationManager<SheetRoute, FullScreenRoute, DialogRoute, StackRoute>,
        viewID: UUID
    ) {
        self.message = message
        self.nav = nav
        self.viewID = viewID
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            Text(message)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)

            Button("Dismiss") {
                nav.dismissSheet(for: viewID)
                nav.dismissFullScreen(for: viewID)
                nav.dismissDialog(for: viewID)
                nav.popToRoot()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

public extension FallbackView {
    static func fallback(
        _ message: String,
        nav: AppNavigationManager<SheetRoute, FullScreenRoute, DialogRoute, StackRoute>,
        viewID: UUID
    ) -> FallbackView {
        FallbackView(message: message, nav: nav, viewID: viewID)
    }
}
