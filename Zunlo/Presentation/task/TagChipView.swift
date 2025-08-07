//
//  TagChipView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/7/25.
//

import SwiftUI

struct TagChipView: View {
    var tag: Tag
    let showDelete: Bool
    @Binding var tags: [Tag]

    var body: some View {
        HStack(spacing: 6) {
            Text(tag.text)
                .themedFootnote()
                .padding(.leading, 10)
                .padding(.trailing, showDelete ? 0 : 10)
                .padding(.vertical, 6)


            if showDelete {
                Button(action: { deleteTag() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(tag.selected ? .white : Color.theme.text)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(tag.selected ? Color.theme.accent : tag.color)
        )
        .onTapGesture {
            toggleSelection()
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
}
