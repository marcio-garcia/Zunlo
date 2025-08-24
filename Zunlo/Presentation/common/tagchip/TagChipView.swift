//
//  TagChipView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/7/25.
//

import SwiftUI
import GlowUI

struct TagChipView: View {
    let tag: Tag
    let showDelete: Bool
    let selectable: Bool
    let type: ChipType
    @Binding var tags: [Tag]
    
    var body: some View {
        HStack(spacing: 6) {
            Text(tag.text)
                .font(type.font)
                .foregroundColor(tag.selected ? .white : Color.theme.text)
                .padding(.vertical, type.verticalPadding)

            if showDelete {
                Button {
                    deleteTag()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(tag.selected ? .white : Color.theme.text)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(
            Capsule()
                .fill(tag.selected ? Color.theme.accent :  Color(hex: Theme.highlightColor(for: tag.text)) ?? Color.theme.disabled)
        )
        .onTapGesture {
            if selectable { toggleSelection() }
        }
    }

    private func deleteTag() {
        if let index = tags.firstIndex(of: tag) {
            tags.remove(at: index)
        }
    }

    private func toggleSelection() {
        if let index = tags.firstIndex(of: tag) {
            tags[index].selected.toggle()
        }
    }
    
    enum ChipType {
        case large
        case small
        
        var font: Font {
            switch self {
            case .large: AppFontStyle.strongCaption.font()
            case .small: AppFontStyle.footnote.font()
            }
        }
        
        var verticalPadding: Double {
            switch self {
            case .large: 6
            case .small: 3
            }
        }
    }
}
