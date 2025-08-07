//
//  SettingsViewFactory.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/7/25.
//

import SwiftUI

struct SettingsViewFactory: SettingsViews {
    
    let authManager: AuthManager
    
    func buildSettingsView() -> AnyView {
        AnyView(SettingsView(authManager: authManager))
    }
}
