//
//  AppSettings.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/23/25.
//

import SwiftUI

enum DefaultsKeys {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
}


final class AppSettings: ObservableObject {
    @AppStorage(DefaultsKeys.hasCompletedOnboarding) var hasCompletedOnboarding: Bool = false
}
