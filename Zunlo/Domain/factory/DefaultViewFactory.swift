//
//  DefaultViewFactory.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import Foundation
import SmartParseKit

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

        let calendar = Calendar.appDefault
        
        let aiChatService = SupabaseAIChatClient(
            supabase: appState.supabaseClient!,
            config: SupabaseAIChatConfig(responseType: .tools)
        )
        let aiToolRepo = AIToolServiceRepository(taskRepo: appState.userTaskRepository!,
                                                 eventRepo: appState.eventRepository!)
        let aiToolService = AIToolService(
            userId: appState.authManager!.userId!,
            toolRepo: aiToolRepo,
            client: appState.supabaseClient!
        )
        let aiToolRouter = AIToolRouter(
            userId: appState.authManager!.userId!,
            tools: aiToolService,
            repo: aiToolRepo,
            calendar: calendar
        )
        
//        Task {
//            do {
//                let env = AIToolEnvelope(
//                    name: "createTask",
//                    argsJSON: "{\"idempotencyKey\": \"abc-5678\",\"intent\": \"create\",\"reason\": \"The reason\",\"dryRun\": true,\"task\": {\"title\": \"Buy new toaster 3\",\"notes\": null,\"isCompleted\": false,\"dueDate\": \"2023-10-06T00:00:00\",\"priority\": \"medium\",\"tags\": [],\"reminderTriggers\": [],\"parentEventId\": null}}")
//                let result = try await aiToolRouter.dispatch(env)
//                print(result)
//            } catch {
//                print(error.localizedDescription)
//            }
//        }
//        Task {
//            let messages = try await appState.chatRepository!.loadMessages(conversationId: cid, limit: nil)
//            let sorted = messages.sorted { $0.createdAt < $1.createdAt }
//            if let msg = sorted.last {
//                var up = msg
//                up.format = .markdown
//                try await appState.chatRepository!.upsert(up)
//            }
//        }
        
        let engine = AppleIntentDetector.bundled()
        let parser = TemporalComposer(prefs: Preferences(calendar: calendar))
        let nlpService = NLService(parser: parser, engine: engine, calendar: calendar)

        let tools = ActionTools(events: appState.eventRepository!,
                                tasks: appState.userTaskRepository!,
                                calendar: calendar)

        let aiChatEngine = ChatEngine(
            conversationId: cid,
            ai: aiChatService,
            nlpService: nlpService,
            tools: aiToolRouter,
            repo: appState.chatRepository!,
            localTools: tools)
        
        return ChatViewModel(
            conversationId: cid,
            engine: aiChatEngine,
            repo: appState.chatRepository!,
            calendar: calendar
        )
    }
}
