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

    func generateDemoData() async {
        if let userId = await appState.authManager?.userId, let localDB = appState.localDB, userId.uuidString.lowercased() == "a555935e-f684-4d81-b1f5-2e234071e799" {
            let dataGenerator = DemoDataGenerator(userId: userId, db: localDB)
            try? await dataGenerator.generateDemoData()
        }
    }
    
    func syncDB() async {
        guard (await appState.authManager?.userId) != nil else {
            state = .error("Need authentication")
            fatalError("DB sync needs authentication")
        }
        
        guard let localDB = appState.localDB else { return }
                
        let sync = SyncCoordinator(db: localDB, supabase: appState.supabaseClient!)
        
        do {
            let _ = try await sync.syncAllOnLaunch()
            await MainActor.run { self.state = .loaded }
        } catch {
            print("Sync error: \(error)")
        }
    }
}
