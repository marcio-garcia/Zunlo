//
//  TagEditorView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/20/25.
//

import SwiftUI

struct TagEditorView: UIViewControllerRepresentable {
    @Binding var tags: [Tag]

    func makeUIViewController(context: Context) -> TagCollectionViewController {
        let controller = TagCollectionViewController()
        controller.tags = tags
        controller.onTagsChanged = { updatedTags in
            self.tags = updatedTags
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: TagCollectionViewController, context: Context) {
        uiViewController.tags = tags
    }
}
