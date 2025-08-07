//
//  LeftAlignedCollectionViewFlowLayout.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/20/25.
//

import UIKit

class LeftAlignedCollectionViewFlowLayout: UICollectionViewFlowLayout {

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let attributes = super.layoutAttributesForElements(in: rect) else {
            return nil
        }

        var leftMargin = sectionInset.left
        var maxY: CGFloat = -1.0

        attributes.forEach { layoutAttribute in
            if layoutAttribute.representedElementCategory != .cell { return }

            if layoutAttribute.frame.origin.y >= maxY {
                leftMargin = sectionInset.left
            }

            layoutAttribute.frame.origin.x = leftMargin
            leftMargin += layoutAttribute.frame.width + minimumInteritemSpacing
            maxY = max(layoutAttribute.frame.maxY, maxY)
        }

        return attributes
    }

    override var collectionViewContentSize: CGSize {
        guard let collectionView = collectionView else { return .zero }

        // Force layout pass to ensure cells are sized
        collectionView.layoutIfNeeded()

        let attributes = layoutAttributesForElements(in: CGRect(origin: .zero, size: collectionView.bounds.size))?
            .filter { $0.representedElementCategory == .cell } ?? []

        guard !attributes.isEmpty else { return .zero }

        var rowCount = 1
        var currentRowWidth: CGFloat = 0
        let availableWidth = collectionView.bounds.width - sectionInset.left - sectionInset.right

        for attr in attributes {
            let width = attr.frame.width
            if currentRowWidth + width > availableWidth {
                rowCount += 1
                currentRowWidth = width + minimumInteritemSpacing
            } else {
                currentRowWidth += width + minimumInteritemSpacing
            }
        }

        let height = CGFloat(rowCount) * 32 + // fixed height
                     CGFloat(rowCount - 1) * minimumLineSpacing +
                     sectionInset.top + sectionInset.bottom

        return CGSize(width: collectionView.bounds.width, height: height)
    }
}
