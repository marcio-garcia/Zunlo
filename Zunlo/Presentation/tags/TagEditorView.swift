//
//  TagEditorView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/20/25.
//

import SwiftUI

struct TagEditorView: UIViewControllerRepresentable {
    @Binding var tags: [Tag]
    var readOnly: Bool = false
    var onTagTapped: ((Set<Tag>) -> Void)? = nil
    
    func makeUIViewController(context: Context) -> TagCollectionViewController {
        let controller = TagCollectionViewController()
        controller.tags = tags
        controller.readOnly = readOnly
        controller.onTagsChanged = { updatedTags in
            self.tags = updatedTags
        }
        controller.onTagTapped = onTagTapped
        return controller
    }

    func updateUIViewController(_ uiViewController: TagCollectionViewController, context: Context) {
        uiViewController.tags = tags
        uiViewController.readOnly = readOnly
        uiViewController.onTagTapped = onTagTapped
    }
}
