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

    let spacing: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.headline)

            FlexibleView(data: tags + [newTag], spacing: spacing, alignment: .leading) { tag in
                if tag == newTag {
                    TextField("Add tag", text: $newTag)
                        .textFieldStyle(.plain)
                        .focused($isInputFocused)
                        .onSubmit {
                            commitNewTag()
                        }
                        .frame(height: 30)
                        .padding(.horizontal, 12)
                        .background(Capsule().fill(Color.gray.opacity(0.1)))
                } else {
                    HStack(spacing: 6) {
                        Text(tag)
                        Image(systemName: "xmark.circle.fill")
                            .onTapGesture {
                                remove(tag: tag)
                            }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.accentColor.opacity(0.2)))
                    .foregroundColor(Color.accentColor)
                    .font(.subheadline)
                }
            }

            // Optional: tap to focus
            Button("Add Tag") {
                isInputFocused = true
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .onAppear {
            // Autofocus if desired
        }
    }

    private func commitNewTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        newTag = ""
    }

    private func remove(tag: String) {
        tags.removeAll { $0 == tag }
    }
}

