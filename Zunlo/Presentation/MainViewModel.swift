//
//  MainViewModel.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import SwiftUI
import Supabase

final class MainViewModel: ObservableObject {
    @Published var state: ViewState = .loading
    
    let appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    func syncDB() async {
        guard (appState.authManager?.userId) != nil else {
            state = .error("Need authentication")
            fatalError("DB sync needs authentication")
        }
        
        guard let localDB = appState.localDB else { return }
        
        let supabaseSwift = SupabaseClient(
            supabaseURL: URL(string: EnvConfig.shared.apiBaseUrl)!,
            supabaseKey: EnvConfig.shared.apiKey
        )
        
        let sync = SyncCoordinator(db: localDB, supabase: supabaseSwift)
        
        await sync.syncAllOnLaunch()
        await MainActor.run { self.state = .loaded }
        
    }
}
