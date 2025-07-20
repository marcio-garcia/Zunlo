//
//  UpgradeFlowService.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/19/25.
//

import SwiftUI

class UpgradeFlowManager: ObservableObject {
    @Published var shouldShowUpgradeFlow = false

    init() {
        NotificationCenter.default.addObserver(forName: .showUpgradeFlow, object: nil, queue: .main) { _ in
            self.shouldShowUpgradeFlow = true
        }
    }
}
