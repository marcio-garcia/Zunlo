//
//  EditableTagInputView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/18/25.
//

import SwiftUI

struct EditableTagInputView: View {
    @Binding var tags: [String]
    @State private var newTag: String = ""
    @FocusState private var isInputFocused: Bool

    private let spacing: CGFloat = 8
    private let minTagWidth: CGFloat = 80

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: minTagWidth), spacing: spacing)], spacing: spacing) {
                ForEach(tags, id: \.self) { tag in
                    TagChip(tag: tag) {
                        remove(tag: tag)
                    }
                }

                TextField("Add tag", text: $newTag)
                    .textFieldStyle(.plain)
                    .focused($isInputFocused)
                    .onSubmit {
                        commitNewTag()
                    }
                    .onChange(of: newTag) { _, _ in
                        autoCommitOnDelimiter()
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(Capsule().fill(Color.gray.opacity(0.1)))
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.default, value: tags)
    }

    private func commitNewTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else {
            newTag = ""
            return
        }
        tags.append(trimmed)
        newTag = ""
    }

    private func autoCommitOnDelimiter() {
        if newTag.contains(",") || newTag.contains(" ") {
            newTag = newTag.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: " ", with: "")
            commitNewTag()
        }
    }

    private func remove(tag: String) {
        tags.removeAll { $0 == tag }
    }
}

struct TagChip: View {
    let tag: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(truncated(tag))
                .lineLimit(1)
                .truncationMode(.tail)
                .fixedSize(horizontal: true, vertical: false)
            Image(systemName: "xmark.circle.fill")
                .onTapGesture { onRemove() }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.accentColor.opacity(0.2)))
        .foregroundColor(Color.accentColor)
        .font(.subheadline)
    }
    
    private func truncated(_ string: String) -> String {
        if string.count > 10 {
            let prefix = string.prefix(10)
            return String(prefix) + "…"
        } else {
            return string
        }
    }
}
