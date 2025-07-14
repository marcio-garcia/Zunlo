//
//  ChatScreenView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import SwiftUI

struct ChatScreenView: View {
    var namespace: Namespace.ID
    @Binding var showChat: Bool
    @StateObject private var viewModel: ChatScreenViewModel

    init(namespace: Namespace.ID, showChat: Binding<Bool>, factory: ViewFactory) {
        self.namespace = namespace
        self._showChat = showChat
        self._viewModel = StateObject(wrappedValue: factory.makeChatScreenViewModel())
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    showChat = false
                }) {
                    Image(systemName: "chevron.backward")
                        .foregroundColor(.primary)
                }
                Spacer()
            }
            .padding()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            Text(message.message)
                                .padding()
                                .background(message.isFromUser ? Color.accentColor.opacity(0.2) : Color.accentColor.opacity(0.5))
                                .cornerRadius(12)
                                .frame(maxWidth: .infinity, alignment: message.isFromUser ? .trailing : .leading)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let last = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.accentColor)
                    TextField("Type a message...", text: $viewModel.messageText)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, minHeight: 42, maxHeight: 42)
                .matchedGeometryEffect(id: "chatMorph", in: namespace)
                
                Button(action: {
                    Task { await viewModel.sendMessage() }
                }) {
                    Image(systemName: "paperplane")
                        .foregroundColor(.primary)
                }
            }
            .padding()
        }
        .background(Color.white.ignoresSafeArea())
        .task { await viewModel.loadHistory() }
    }
}
