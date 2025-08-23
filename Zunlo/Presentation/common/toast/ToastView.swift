//
//  ToastView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/16/25.
//

import SwiftUI

public enum ToastPosition { case top, bottom }

struct ToastView: View {
    let message: String
    let onDismiss: () -> Void
    
    @State private var yOffset: CGFloat = 0
    @State private var isAppeared = false
    
    var body: some View {
        Text(message)
            .font(AppFontStyle.callout.font())
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.theme.accent)
            )
            .shadow(radius: 12, y: 4)
            .offset(y: yOffset)
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        // Follow vertical drag a bit for feel; cap to avoid huge offsets
                        yOffset = max(-120, min(120, value.translation.height))
                    }
                    .onEnded { value in
                        let magnitude = hypot(value.translation.height, value.translation.width)
                        if magnitude > 40 {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                                yOffset = value.translation.height >= 0 ? 160 : -160
                            }
                            onDismiss()
                        } else {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                                yOffset = 0
                            }
                        }
                    }
            )
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Modifier

struct ToastPresenter: ViewModifier {
    @Binding var toast: Toast?
    var position: ToastPosition = .bottom
    
    @State private var dismissTask: Task<Void, Never>?
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: position == .top ? .top : .bottom) {
                Group {
                    if let toast {
                        ToastView(message: toast.message, onDismiss: dismiss)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 24)
                            .transition(.move(edge: position == .top ? .top : .bottom).combined(with: .opacity))
                            .onAppear { startTimer(for: toast.duration) }
                            .onDisappear { cancelTimer() }
                            .zIndex(10)
                    }
                }
                .animation(.spring(response: 0.32, dampingFraction: 0.9), value: toast?.id)
            }
            // Restart timer on new toast value
            .onChange(of: toast?.id) { _, _ in
                if let t = toast {
                    startTimer(for: t.duration)
                } else {
                    cancelTimer()
                }
            }
    }
    
    private func startTimer(for seconds: TimeInterval) {
        cancelTimer()
        guard seconds > 0 else { return }
        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
            if !Task.isCancelled { dismiss() }
        }
    }
    
    private func cancelTimer() {
        dismissTask?.cancel()
        dismissTask = nil
    }
    
    private func dismiss() {
        cancelTimer()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            toast = nil
        }
    }
}

// MARK: - API

public extension View {
    /// Present a toast using an optional `Toast` binding.
    func toast(_ toast: Binding<Toast?>, position: ToastPosition = .bottom) -> some View {
        modifier(ToastPresenter(toast: toast, position: position))
    }
    
    /// Convenience for boolean presentation with a fixed message.
    func toast(_ message: String,
               isPresented: Binding<Bool>,
               duration: TimeInterval = 5,
               position: ToastPosition = .bottom) -> some View {
        let binding = Binding<Toast?>(
            get: { isPresented.wrappedValue ? Toast(message, duration: duration) : nil },
            set: { newValue in isPresented.wrappedValue = (newValue != nil) }
        )
        return modifier(ToastPresenter(toast: binding, position: position))
    }
}
