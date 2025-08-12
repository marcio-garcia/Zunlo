//
//  TagChipListView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/8/25.
//

import SwiftUI

struct TagChipListView: View {
    @Binding var tags: [Tag]
    var mode: Mode = .readonly(true)
    var chipType: TagChipView.ChipType = .large
    var onTagsChanged: (([Tag]) async -> Void)? = nil
    var allPossibleTags: [String] = [] // Autocomplete pool

    @State private var newTagText: String = ""
    @State private var shakeInput: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tags) { tag in
                        TagChipView(
                            tag: tag,
                            showDelete: mode == .editable,
                            selectable: isSelectable(mode),
                            type: chipType,
                            tags: $tags
                        )
                    }
                }
                .padding(.horizontal)
            }

            if mode == .editable {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        TextField("Add tag", text: $newTagText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(AppFontStyle.strongCaption.font())
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(
                                Capsule()
                                    .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                                    .modifier(ShakeEffect(shakes: shakeInput ? 2 : 0))
                            )
                            .submitLabel(.done)
                            .onSubmit {
                                addTag()
                            }
                    }

                    // Autocomplete suggestion list
                    if !filteredSuggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(filteredSuggestions, id: \.self) { suggestion in
                                    Button {
                                        newTagText = suggestion
                                        addTag()
                                    } label: {
                                        Text(suggestion)
                                            .font(AppFontStyle.strongCaption.font())
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 10)
                                            .background(
                                                Capsule().fill(Color.gray.opacity(0.2))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal)
                .animation(.easeInOut, value: newTagText)
            }
        }
        .onChange(of: tags) { oldValue, newValue in
            Task { await onTagsChanged?(newValue) }
        }
    }

    private func isSelectable(_ mode: Mode) -> Bool {
        if case .readonly(let selectable) = mode {
            return selectable
        }
        return false
    }
    
    private var filteredSuggestions: [String] {
        let lowercaseInput = newTagText.lowercased()
        guard !lowercaseInput.isEmpty else { return [] }

        let existing = Set(tags.map { $0.text.lowercased() })
        return allPossibleTags
            .map { $0.lowercased() }
            .filter { $0.hasPrefix(lowercaseInput) && !existing.contains($0) }
            .sorted()
    }

    private func addTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return }

        if tags.contains(where: { $0.text.lowercased() == trimmed }) {
            triggerShake()
            newTagText = ""
            return
        }

        tags.append(
            Tag(id: UUID(), text: trimmed, color: Color.theme.accent.hexString(), selected: false)
        )
        tags.sort { $0.text.localizedCompare($1.text) == .orderedAscending }

        newTagText = ""
    }

    private func triggerShake() {
        shakeInput = true

        // Trigger haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()

        // Reset shake after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            shakeInput = false
        }
    }
}

extension TagChipListView {
    enum Mode: Equatable {
        case editable
        case readonly(_ selectable: Bool)
    }
}
