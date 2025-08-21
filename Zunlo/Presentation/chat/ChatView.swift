//
//  ChatView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import SwiftUI

struct ChatView: View {
    var namespace: Namespace.ID
    @Binding var showChat: Bool
    @StateObject private var viewModel: ChatViewModel

    @FocusState private var focused: Bool
    @State private var scrollProxy: ScrollViewProxy?

    private let calendar = Calendar.current
    
    init(namespace: Namespace.ID, showChat: Binding<Bool>, factory: ViewFactory) {
        self.namespace = namespace
        self._showChat = showChat
        // Factory should be updated to provide conversationId, repository, ai
        self._viewModel = StateObject(wrappedValue: factory.makeChatScreenViewModel())
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            messageList
            if !viewModel.suggestions.isEmpty { suggestionChips }
            inputBar
        }
        .defaultBackground()
        .task { await viewModel.loadHistory() }
//        .onChange(of: viewModel.messages.count) { _, _ in scrollToBottom(animated: true) }
        .swipeToDismiss(isPresented: $showChat, threshold: 300, predictedThreshold: 300, minOpacity: 0.7)
        .matchedGeometryEffect(id: "chatScreen", in: namespace, isSource: showChat)
    }

    private var header: some View {
        HStack {
            Button { showChat = false } label: {
                Image(systemName: "chevron.backward").font(.headline)
            }
            Spacer()
            Text("Zunlo Assistant").font(.headline)
            Spacer()
            if viewModel.isGenerating {
                Button("Stop") { viewModel.stopGeneration() }
                    .font(.subheadline)
            } else {
                Button { } label: { Image(systemName: "ellipsis") }
            }
        }
        .padding(.horizontal).padding(.top)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.daySections) { section in
                        DaySeparator(title: dayTitle(for: section.date))
                            .id("separator-\(section.id)")

                        ForEach(section.items) { msg in
                            VStack(alignment: msg.role == .user ? .trailing : .leading, spacing: 4) {
                                MessageBubble(message: msg) { action, message in
                                    viewModel.handleBubbleAction(action, message: message)
                                }
                                Text(timeString(for: msg.createdAt))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: msg.role == .user ? .trailing : .leading)
                                    .padding(.horizontal, 6)
                            }
                            .id(msg.id)
                            .contextMenu {
                                Button("Copy") { UIPasteboard.general.string = msg.text }
                                if msg.status == .failed {
                                    Button("Retry") { Task { await viewModel.retry(messageId: msg.id) } }
                                }
                                Button(role: .destructive) { /* delete if desired */ } label: { Text("Delete") }
                            }
                        }
                    }

                    if viewModel.isGenerating {
                        TypingIndicator().accessibilityLabel("Assistant is typing")
                    }
                }
                .padding(.horizontal).padding(.vertical, 8)
            }
            .onAppear { scrollProxy = proxy }
            .onChange(of: viewModel.lastMessageAnchor) { _, id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(id, anchor: .bottom)
                }
            }
        }
    }

    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.suggestions, id: \.self) { chip in
                    Button {
                        Task { await viewModel.send(text: chip) }
                    } label: {
                        Text(chip)
                            .font(.caption)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    }
                }
            }
            .padding(.horizontal).padding(.bottom, 6)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextEditor(text: $viewModel.input)
                .font(.body)
                .padding(10)
                .frame(minHeight: 42, maxHeight: 120)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.secondary.opacity(0.12)))
                .focused($focused)
                .submitLabel(.send)
                .onSubmit { Task { await viewModel.send() } }

            Button {
                Task { await viewModel.send() }
            } label: {
                Image(systemName: "paperplane.fill").font(.title3)
            }
            .disabled(viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isGenerating)
        }
        .padding(.horizontal).padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .matchedGeometryEffect(id: "chatMorph", in: namespace, isSource: showChat)
    }

    private struct DaySeparator: View {
        let title: String
        var body: some View {
            HStack {
                Rectangle().frame(height: 1).opacity(0.12)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(Color.accentColor.opacity(0.10)))
                Rectangle().frame(height: 1).opacity(0.12)
            }
            .padding(.vertical, 6)
        }
    }
    
    private func scrollToBottom(animated: Bool) {
        if let id = viewModel.messages.last?.id {
            withAnimation(animated ? .easeOut(duration: 0.25) : nil) {
                scrollProxy?.scrollTo(id, anchor: .bottom)
            }
        }
    }
    
    private static let headerFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()

    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        return df
    }()

    private func dayTitle(for date: Date) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return Self.headerFormatter.string(from: date)
    }

    private func timeString(for date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    let onAction: (ChatMessageAction, ChatMessage) -> Void   // NEW

    var body: some View {
        HStack {
            if message.role == .assistant || message.role == .tool {
                bubble
                Spacer(minLength: 30)
            } else {
                Spacer(minLength: 30)
                bubble
            }
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message.text)
                .themedBody()

            if !message.actions.isEmpty {
                HStack(spacing: 8) {
                    ForEach(message.actions) { action in
                        Button(action.title) {
                            onAction(action, message)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .clipShape(Capsule())
                    }
                }
                .padding(.top, 2)
            }

            if message.status == .failed, let err = message.errorDescription {
                Text(err).font(.caption2).foregroundStyle(.red)
            } else if message.status == .streaming {
                ProgressView().scaleEffect(0.6)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(message.role == .user
                      ? Color.theme.accent.opacity(0.22)
                      : Color.theme.accent.opacity(0.10))
        )
    }
}


private struct TypingIndicator: View {
    var body: some View {
        HStack(spacing: 6) {
            Circle().frame(width: 6, height: 6)
            Circle().frame(width: 6, height: 6)
            Circle().frame(width: 6, height: 6)
        }
        .opacity(0.6)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.08)))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// Tighter timestamp placement inside bubbles

//private struct MessageBubble: View {
//    let message: ChatMessage
//
//    var body: some View {
//        HStack {
//            if message.role == .assistant || message.role == .tool {
//                bubble(alignment: .leading)
//                Spacer(minLength: 30)
//            } else {
//                Spacer(minLength: 30)
//                bubble(alignment: .trailing)
//            }
//        }
//    }
//
//    private func bubble(alignment: HorizontalAlignment) -> some View {
//        VStack(alignment: alignment, spacing: 6) {
//            Text(message.text)
//                .font(.body)
//                .foregroundStyle(.primary)
//
//            HStack {
//                if alignment == .leading {
//                    Text(Self.timeFormatter.string(from: message.createdAt))
//                        .font(.caption2).foregroundStyle(.secondary)
//                    Spacer(minLength: 0)
//                } else {
//                    Spacer(minLength: 0)
//                    Text(Self.timeFormatter.string(from: message.createdAt))
//                        .font(.caption2).foregroundStyle(.secondary)
//                }
//            }
//
//            if message.status == .failed, let err = message.errorDescription {
//                Text(err).font(.caption2).foregroundStyle(.red)
//            } else if message.status == .streaming {
//                ProgressView().scaleEffect(0.6)
//            }
//        }
//        .padding(12)
//        .background(
//            RoundedRectangle(cornerRadius: 14)
//                .fill(message.role == .user
//                      ? Color.accentColor.opacity(0.22)
//                      : Color.accentColor.opacity(0.10))
//        )
//    }
//
//    private static let timeFormatter: DateFormatter = {
//        let df = DateFormatter()
//        df.dateStyle = .none
//        df.timeStyle = .short
//        return df
//    }()
//}
