//
//  CAShapeLayer+Corners.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/11/25.
//

import UIKit

extension CAShapeLayer {
    static func roundCorners(
        for corners: UIRectCorner,
        bounds: CGRect,
        radius: CGFloat
    ) -> CAShapeLayer {
        let maskPath = UIBezierPath(
            roundedRect: bounds,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.frame = bounds
        shapeLayer.path = maskPath.cgPath
        
        // Set the mask of the view's layer
        return shapeLayer
    }
}
