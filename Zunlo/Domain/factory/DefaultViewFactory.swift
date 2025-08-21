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

        let aiChatService = SupabaseEdgeAIClient(supabase: appState.supabaseClient!)
        let aiToolRepo = AIToolServiceRepository(taskRepo: appState.userTaskRepository!,
                                                 eventRepo: appState.eventRepository!)
        let aiToolService = AIToolService(toolRepo: aiToolRepo, client: appState.supabaseClient!)
        let aiToolRouter = AIToolRouter(tools: aiToolService, repo: aiToolRepo)
        return ChatViewModel(
            conversationId: cid,
            userId: appState.authManager?.user?.id,
            aiChatService: aiChatService,
            toolRouter: aiToolRouter,
            chatRepo: appState.chatRepository!
        )
    }
}
