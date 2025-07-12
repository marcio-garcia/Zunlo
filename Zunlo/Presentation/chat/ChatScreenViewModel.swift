//
//  ChatScreenViewModel.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import SwiftUI

final class ChatScreenViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var messageText: String = ""

    private let repository: ChatRepository

    init(repository: ChatRepository) {
        self.repository = repository
    }

    func loadHistory() async {
        do {
            let result = try await repository.loadMessages()
            await MainActor.run {
                self.messages = result
            }
        } catch {
            print("Failed to load chat history: \(error)")
        }
    }

    func sendMessage() async {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = ChatMessage(
            id: UUID(),
            userId: nil,
            message: text,
            createdAt: Date(),
            isFromUser: true
        )

        await MainActor.run {
            messages.append(userMessage)
            messageText = ""
        }

        do {
            try await repository.sendMessage(text, fromUser: true)
        } catch {
            print("Failed to save message: \(error)")
        }
    }
}
