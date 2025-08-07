//
//  SettingsViewRouter.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/7/25.
//

import SwiftUI
import FlowNavigator

struct SettingsViewRouter {
    static func sheetView(
        for route: SheetRoute,
        nav: AppNav,
        factory: SettingsViews
    ) -> AnyView? {
        guard case .settings = route else { return nil }
        return factory.buildSettingsView()
    }
}
