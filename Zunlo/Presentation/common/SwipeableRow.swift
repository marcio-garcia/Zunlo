//
//  SwipeableRow.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/9/25.
//

import SwiftUI

struct SwipeableRow<Content: View>: View {
    @State private var offset: CGFloat = 0
    
    let id: UUID
    let isOpen: Bool
    let content: () -> Content
    let onOpen: () -> Void
    let onClose: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        ZStack(alignment: .trailing) {
            HStack {
                Spacer()
                HStack(spacing: 0) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .frame(width: 60, height: 60)
                            .background(Color.purple.opacity(0.2))
                    }
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .frame(width: 60, height: 60)
                            .background(Color.red.opacity(0.2))
                    }
                }
            }
            content()
                .background(Color.white)
                .offset(x: offset)
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width < 0 {
                                offset = max(value.translation.width, -120)
                                if !isOpen && offset < -10 {
                                    onOpen()
                                }
                            }
                        }
                        .onEnded { value in
                            if value.translation.width < -60 {
                                offset = -120
                                onOpen()
                            } else {
                                offset = 0
                                onClose()
                            }
                        }
                )
                .onChange(of: isOpen) {
                    if !isOpen {
                        offset = 0
                    }
                    if isOpen && offset == 0 {
                        offset = -120
                    }
                }
        }
        .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.7), value: offset)
    }
}
