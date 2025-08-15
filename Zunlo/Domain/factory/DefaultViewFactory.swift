//
//  DefaultViewFactory.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import Foundation

protocol ViewFactory {
    func makeMainViewModel() -> MainViewModel
    @MainActor func makeChatScreenViewModel() -> ChatViewModel
}

final class DefaultViewFactory: ViewFactory {
    let appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
    }

    func makeMainViewModel() -> MainViewModel {
        return MainViewModel(appState: appState)
    }
    
    @MainActor
    func makeChatScreenViewModel() -> ChatViewModel {
        var cid = UUID()
        
        // Resolve the single conversation id quickly from defaults (creating the row if needed)
        do {
            cid = try DefaultsConversationIDStore().getOrCreate()
        } catch {
            print("Error creating ChatViewModel - \(error.localizedDescription)")
        }
        
        // Ensure the Conversation row exists without blocking init
        Task { try? await appState.localDB!.ensureConversationExists(id: cid) }

        let store = RealmChatLocalStore(db: appState.localDB!)
        let repo = DefaultChatRepository(store: store)
        let ai = NoopAIClient()

        return ChatViewModel(conversationId: cid, repository: repo, ai: ai, userId: appState.authManager?.user?.id)
    }
}
