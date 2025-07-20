//
//  MainViewModel.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import SwiftUI

final class MainViewModel: ObservableObject {
    let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }
}
