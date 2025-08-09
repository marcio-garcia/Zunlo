//
//  TagCollectionViewController.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/20/25.
//

import UIKit

class TagCollectionViewController: UIViewController, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    var tags: [Tag] = [] {
        didSet {
            if isViewLoaded {
                collectionView.reloadData()
                collectionView.layoutIfNeeded()
//                let contentHeight = collectionView.collectionViewLayout.collectionViewContentSize.height
//                onHeightChanged?(contentHeight)
            }
        }
    }

    var onTagsChanged: (([Tag]) -> Void)?
    var onTagTapped: ((Tag) -> Void)?
    var onHeightChanged: ((CGFloat) -> Void)?
    
    var readOnly: Bool = false
    
    private var selectedTags: Set<Tag> = []
    private var collectionView: UICollectionView!

    override func viewDidLoad() {
        super.viewDidLoad()

        let layout = LeftAlignedCollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.itemSize = .zero
        layout.estimatedItemSize = CGSize(width: 100, height: 32) // arbitrary width

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.register(TagCell.self, forCellWithReuseIdentifier: TagCell.reuseIdentifier)
        collectionView.register(AddTagCell.self, forCellWithReuseIdentifier: AddTagCell.reuseIdentifier)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isScrollEnabled = true
        collectionView.backgroundColor = .clear
        collectionView.allowsSelection = false
        
        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let contentHeight = collectionView.collectionViewLayout.collectionViewContentSize.height
        if view.bounds.height != contentHeight {
            onHeightChanged?(contentHeight)
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        readOnly ? tags.count : tags.count + 1 // +1 for add tag chip
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.item < tags.count {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TagCell.reuseIdentifier, for: indexPath) as! TagCell
            let tag = tags[indexPath.item]
            cell.configure(with: tag, showDelete: !readOnly) { [weak self] in
                guard let self, !readOnly else { return }
                self.tags.removeAll { $0.id == tag.id }
                self.onTagsChanged?(self.tags)
            }
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AddTagCell.reuseIdentifier, for: indexPath) as! AddTagCell
            cell.onAdd = { text in
                let newTag = Tag(id: UUID(), text: text, color: "#55FF66", selected: false)
                self.tags.append(newTag)
                self.onTagsChanged?(self.tags)
                self.collectionView.reloadData()
            }
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < tags.count else { return }

        let tag = tags[indexPath.item]
        tags[indexPath.item].selected.toggle()
        onTagsChanged?(tags)
        collectionView.reloadItems(at: [indexPath])
        onTagTapped?(tag)
    }
}
