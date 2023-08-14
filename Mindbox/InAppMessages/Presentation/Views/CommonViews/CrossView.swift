//
//  CrossView.swift
//  Mindbox
//
//  Created by vailence on 21.07.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import UIKit

class CrossView: UIView {
    
    var lineColor: UIColor = .black
    var lineWidth: CGFloat = 1.0
    var padding: CGFloat = 2.0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupDefaults()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDefaults()
    }
    
    convenience init(lineColorHex: String?, lineWidth: Int?) {
        self.init()
        setupView(lineColorHex: lineColorHex, lineWidth: lineWidth)
    }
    
    private func setupDefaults() {
        backgroundColor = .clear
    }
    
    private func setupView(lineColorHex: String?, lineWidth: Int?) {
        let color = lineColorHex ?? "#000000"
        let width = lineWidth ?? 1
        self.lineColor = UIColor(hex: color)
        self.lineWidth = CGFloat(width)
    }

    override func draw(_ rect: CGRect) {
        let path = drawCross(in: rect)
        strokePath(path)
    }
    
    private func drawCross(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        path.lineWidth = lineWidth
        path.lineCapStyle = .round

        let centerX = rect.width / 2
        let centerY = rect.height / 2
        let halfWidth = (rect.width - padding * 2) / 2
        let halfHeight = (rect.height - padding * 2) / 2

        let leftTop = CGPoint(x: centerX - halfWidth, y: centerY - halfHeight)
        let rightBottom = CGPoint(x: centerX + halfWidth, y: centerY + halfHeight)
        let rightTop = CGPoint(x: centerX + halfWidth, y: centerY - halfHeight)
        let leftBottom = CGPoint(x: centerX - halfWidth, y: centerY + halfHeight)

        path.move(to: leftTop)
        path.addLine(to: rightBottom)
        path.move(to: rightTop)
        path.addLine(to: leftBottom)
        
        return path
    }
    
    private func strokePath(_ path: UIBezierPath) {
        lineColor.setStroke()
        path.stroke()
        addShapeLayer(for: path)
    }
    
    private func addShapeLayer(for path: UIBezierPath) {
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = lineColor.cgColor
        shapeLayer.lineWidth = lineWidth
        shapeLayer.lineCap = .round
        self.layer.addSublayer(shapeLayer)
    }
}
