//
//  ChatScreenView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import SwiftUI

struct ChatScreenView: View {
    let namespace: Namespace.ID
    @Binding var isPresented: Bool
    @StateObject private var viewModel: ChatScreenViewModel

    init(namespace: Namespace.ID, isPresented: Binding<Bool>, factory: ViewFactory) {
        self.namespace = namespace
        self._isPresented = isPresented
        self._viewModel = StateObject(wrappedValue: factory.makeChatScreenViewModel())
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    withAnimation(.spring()) {
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.title2)
                        .padding()
                }
                Spacer()
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            Text(message.message)
                                .padding()
                                .background(message.isFromUser ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
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
                TextField("Type a message...", text: $viewModel.messageText)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .matchedGeometryEffect(id: "chatBar", in: namespace)

                Button("Send") {
                    Task { await viewModel.sendMessage() }
                }
            }
            .padding()
        }
        .background(Color.white.ignoresSafeArea())
        .task { await viewModel.loadHistory() }
    }
}
