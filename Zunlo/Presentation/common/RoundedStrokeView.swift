//
//  RoundedStrokeView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/11/25.
//

import UIKit

final class RoundedStrokeView: UIView {

    // MARK: Public knobs
    var corners: UIRectCorner = .allCorners { didSet { setNeedsLayout() } }
    var strokedEdges: UIRectEdge = .all { didSet { setNeedsLayout() } }

    var cornerRadius: CGFloat = 16 { didSet { setNeedsLayout() } }
    var borderWidth: CGFloat = 1 { didSet { setNeedsLayout() } }
    var borderColor: UIColor = .separator { didSet { borderLayer.strokeColor = borderColor.cgColor } }
    var fillColor: UIColor? = .clear { didSet { fillLayer.fillColor = fillColor?.cgColor ?? UIColor.clear.cgColor } }
    var contentInset: UIEdgeInsets = .zero { didSet { setNeedsLayout() } }

    // MARK: Layers
    private let fillLayer = CAShapeLayer()
    private let borderLayer = CAShapeLayer()
    
    private let effect = UIBlurEffect(style: UIBlurEffect.Style.light)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        fillLayer.fillColor = UIColor.clear.cgColor
        layer.addSublayer(fillLayer)

        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.lineJoin = .round
        borderLayer.lineCap  = .square
        layer.addSublayer(borderLayer)
        
        let blur = UIBlurEffect(style: .systemUltraThinMaterial)
        let blurView = UIVisualEffectView(effect: blur)
        blurView.frame = bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.isUserInteractionEnabled = false
        insertSubview(blurView, at: 0)
    }
    
    required init?(coder: NSCoder) { fatalError("Not implemented!") }

    override func layoutSubviews() {
        super.layoutSubviews()

        // 1) Build rects
        let fillRect = bounds.inset(by: contentInset)                 // full fill (no half inset)
        let strokeInset = borderWidth / 2.0
        let strokeRect = fillRect.insetBy(dx: strokeInset, dy: strokeInset) // stroke sits inside

        // 2) Fill + mask path (rounded rect)
        let roundedFill = UIBezierPath(
            roundedRect: fillRect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)
        )
        fillLayer.path = roundedFill.cgPath
        fillLayer.fillColor = fillColor?.cgColor ?? UIColor.clear.cgColor

        let mask = CAShapeLayer()
        mask.path = roundedFill.cgPath
        layer.mask = mask

        // 3) Border path (only selected edges + corner arcs)
        borderLayer.strokeColor = borderColor.cgColor
        borderLayer.lineWidth = borderWidth
        borderLayer.path = strokedPerimeter(in: strokeRect).cgPath
    }

    // MARK: - Path Builder

    private func strokedPerimeter(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()

        let scale = window?.screen.scale ?? UIScreen.main.scale
        func snap(_ v: CGFloat) -> CGFloat { round(v * scale) / scale }

        let minX = snap(rect.minX), maxX = snap(rect.maxX)
        let minY = snap(rect.minY), maxY = snap(rect.maxY)

        let r = cornerRadius
        let tl = corners.contains(.topLeft)     ? r : 0
        let tr = corners.contains(.topRight)    ? r : 0
        let bl = corners.contains(.bottomLeft)  ? r : 0
        let br = corners.contains(.bottomRight) ? r : 0

        func arc(cx: CGFloat, cy: CGFloat, radius: CGFloat, start: CGFloat, end: CGFloat) {
            guard radius > 0 else { return }
            let cx = snap(cx), cy = snap(cy)
            let sx = snap(cx + cos(start) * radius)
            let sy = snap(cy + sin(start) * radius)
            path.move(to: CGPoint(x: sx, y: sy))     // move to arc's true start
            path.addArc(withCenter: CGPoint(x: cx, y: cy),
                        radius: radius, startAngle: start, endAngle: end, clockwise: true)
        }

        // TOP edge
        if strokedEdges.contains(.top) {
            path.move(to: CGPoint(x: snap(minX + tl), y: minY))
            path.addLine(to: CGPoint(x: snap(maxX - tr), y: minY))
        }
        // RIGHT edge
        if strokedEdges.contains(.right) {
            path.move(to: CGPoint(x: maxX, y: snap(minY + tr)))
            path.addLine(to: CGPoint(x: maxX, y: snap(maxY - br)))
        }
        // BOTTOM edge
        if strokedEdges.contains(.bottom) {
            path.move(to: CGPoint(x: snap(maxX - br), y: maxY))
            path.addLine(to: CGPoint(x: snap(minX + bl), y: maxY))
        }
        // LEFT edge
        if strokedEdges.contains(.left) {
            path.move(to: CGPoint(x: minX, y: snap(maxY - bl)))
            path.addLine(to: CGPoint(x: minX, y: snap(minY + tl)))
        }

        // Corner arcs only when BOTH adjacent edges are stroked
        if strokedEdges.contains([.top, .left]) {
            arc(cx: minX + tl, cy: minY + tl, radius: tl, start: .pi, end: 1.5 * .pi) // TL
        }
        if strokedEdges.contains([.top, .right]) {
            arc(cx: maxX - tr, cy: minY + tr, radius: tr, start: 1.5 * .pi, end: 0)   // TR
        }
        if strokedEdges.contains([.right, .bottom]) {
            arc(cx: maxX - br, cy: maxY - br, radius: br, start: 0, end: .pi/2)       // BR
        }
        if strokedEdges.contains([.bottom, .left]) {
            arc(cx: minX + bl, cy: maxY - bl, radius: bl, start: .pi/2, end: .pi)     // BL
        }

        return path
    }

}


//final class RoundedStrokeView: UIView {
//
//    // Public knobs
//    var corners: UIRectCorner = .allCorners { didSet { setNeedsLayout() } }
//    var cornerRadius: CGFloat = 16 { didSet { setNeedsLayout() } }
//    var borderWidth: CGFloat = 1 { didSet { setNeedsLayout() } }
//    var borderColor: UIColor = .separator { didSet { shape.strokeColor = borderColor.cgColor } }
//    var fillColor: UIColor? = .clear { didSet { shape.fillColor = fillColor?.cgColor ?? UIColor.clear.cgColor } }
//    var contentInset: UIEdgeInsets = .zero { didSet { setNeedsLayout() } }
//
//    private let shape = CAShapeLayer()
//
//    override init(frame: CGRect) {
//        super.init(frame: frame)
//        isOpaque = false
//        shape.lineJoin = .round
//        layer.addSublayer(shape)
//    }
//
//    required init?(coder: NSCoder) { super.init(coder: coder); layer.addSublayer(shape) }
//
//    override func layoutSubviews() {
//        super.layoutSubviews()
//
//        let rect = bounds.inset(by: contentInset)
//        let path = UIBezierPath(
//            roundedRect: rect,
//            byRoundingCorners: corners,
//            cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)
//        )
//
//        // Border
//        shape.path = path.cgPath
//        shape.strokeColor = borderColor.cgColor
//        shape.lineWidth = borderWidth
//        shape.fillColor = fillColor?.cgColor ?? UIColor.clear.cgColor
//
//        // Mask (so the view’s contents clip to the same rounded corners)
//        let mask = CAShapeLayer()
//        mask.path = path.cgPath
//        layer.mask = mask
//    }
//}
