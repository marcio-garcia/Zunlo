//
//  ChatSyncEngine.swift
//  Zunlo
//
//  Created by Marcio Garcia on 1/5/25.
//

import Foundation
import RealmSwift

struct ChatSyncReport {
    let pushed: Int
    let pulled: Int
    let failed: Int
    let abandoned: Int
}

final class ChatSyncEngine {
    private let db: DatabaseActor
    private let api: SyncAPI
    private let pageSize = 100
    private let tableName = "chat_messages"
    private let maxRetryAttempts = 5

    init(db: DatabaseActor, api: SyncAPI) {
        self.db = db
        self.api = api
    }

    // MARK: - Public API

    /// Main sync: push unsynced messages, then pull new ones from server
    func sync() async throws -> ChatSyncReport {
        let pushStats = await pushUnsyncedMessages()
        let pullStats = try await pullNewMessages()

        return ChatSyncReport(
            pushed: pushStats.succeeded,
            pulled: pullStats,
            failed: pushStats.failed,
            abandoned: pushStats.abandoned
        )
    }

    /// Fire-and-forget: immediately try to push a single message
    func trySyncMessage(_ messageId: UUID) async {
        guard let message = try? await db.fetchChatMessageLocal(messageId) else { return }

        // Already synced or abandoned
        guard message.syncStatus == .pending || message.syncStatus == .failed else { return }

        _ = await pushMessage(message)
    }

    // MARK: - Push Logic

    private func pushUnsyncedMessages() async -> (succeeded: Int, failed: Int, abandoned: Int) {
        let messages = (try? await db.readUnsyncedChatMessages()) ?? []
        guard !messages.isEmpty else { return (0, 0, 0) }

        var succeeded = 0
        var failed = 0
        var abandoned = 0

        for message in messages {
            let result = await pushMessage(message)
            switch result {
            case .success: succeeded += 1
            case .failed: failed += 1
            case .abandoned: abandoned += 1
            }
        }

        return (succeeded, failed, abandoned)
    }

    private enum PushResult {
        case success, failed, abandoned
    }

    private func pushMessage(_ message: ChatMessageLocal) async -> PushResult {
        // Skip if already synced or abandoned
        guard message.syncStatus != .synced && message.syncStatus != .abandoned else {
            return .success
        }

        // Check if we've exceeded max attempts
        if message.syncAttempts >= maxRetryAttempts {
            try? await db.updateChatMessageSyncStatus(
                messageId: message.id,
                status: .abandoned,
                attempts: message.syncAttempts,
                error: "Max retry attempts exceeded"
            )
            return .abandoned
        }

        // Update to syncing status
        try? await db.updateChatMessageSyncStatus(
            messageId: message.id,
            status: .syncing,
            attempts: message.syncAttempts,
            error: nil
        )

        do {
            // Convert to remote and push
            let remote = ChatMessageRemote(local: message)
            let payload = ChatMessageInsertPayload(remote: remote)
            let inserted = try await api.insertChatMessagesPayloadReturning([payload])

            // Mark as synced
            if let serverMessage = inserted.first {
                try await db.updateChatMessageSyncStatus(
                    messageId: message.id,
                    status: .synced,
                    attempts: message.syncAttempts,
                    error: nil
                )
                return .success
            } else {
                throw NSError(domain: "ChatSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "No message returned from server"])
            }
        } catch {
            // Mark as failed and increment attempts
            let newAttempts = message.syncAttempts + 1
            let status: ChatSyncStatus = newAttempts >= maxRetryAttempts ? .abandoned : .failed

            try? await db.updateChatMessageSyncStatus(
                messageId: message.id,
                status: status,
                attempts: newAttempts,
                error: error.localizedDescription
            )

            return status == .abandoned ? .abandoned : .failed
        }
    }

    // MARK: - Pull Logic

    private func pullNewMessages() async throws -> Int {
        let (sinceTs, sinceTsRaw, sinceId) = try await db.readCursor(for: tableName)
        var totalPulled = 0

        var currentTs = sinceTs
        var currentTsRaw = sinceTsRaw
        var currentId = sinceId

        while true {
            let since = currentTsRaw ?? RFC3339MicrosUTC.string(currentTs)
            let messages = try await api.fetchChatMessagesToSync(
                sinceTimestamp: since,
                sinceID: currentId,
                pageSize: pageSize
            )

            guard !messages.isEmpty else { break }

            // Apply messages to local DB
            try await db.applyChatMessagesPage(messages)

            // Update cursor
            if let last = messages.last {
                currentTs = last.updatedAt
                currentTsRaw = last.updatedAtRaw
                currentId = last.id
            }

            totalPulled += messages.count
        }

        return totalPulled
    }
}
