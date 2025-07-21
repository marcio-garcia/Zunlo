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
            if isViewLoaded { collectionView.reloadData() }
        }
    }

    var onTagsChanged: (([Tag]) -> Void)?

    private var collectionView: UICollectionView!

    override func viewDidLoad() {
        super.viewDidLoad()

        let layout = LeftAlignedCollectionViewFlowLayout()
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.register(TagCell.self, forCellWithReuseIdentifier: TagCell.reuseIdentifier)
        collectionView.register(AddTagCell.self, forCellWithReuseIdentifier: AddTagCell.reuseIdentifier)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isScrollEnabled = false
        collectionView.backgroundColor = .clear

        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        tags.count + 1 // +1 for add tag chip
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.item < tags.count {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TagCell.reuseIdentifier, for: indexPath) as! TagCell
            let tag = tags[indexPath.item]
            cell.configure(with: tag) {
                self.tags.removeAll { $0.id == tag.id }
                self.onTagsChanged?(self.tags)
            }
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AddTagCell.reuseIdentifier, for: indexPath) as! AddTagCell
            cell.onAdd = { text in
                let newTag = Tag(text: text, color: .systemTeal)
                self.tags.append(newTag)
                self.onTagsChanged?(self.tags)
                self.collectionView.reloadData()
            }
            return cell
        }
    }
}
