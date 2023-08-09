//
//  CloseButtonElementFactory.swift
//  Mindbox
//
//  Created by vailence on 04.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import UIKit

class CloseButtonElementFactory: ElementFactory {
    func create(from element: ContentElement, in view: UIView, with controller: UIViewController) -> UIView? {
        guard let controller = controller as? ModalViewController else {
            return nil
        }
        
        let color = element.color?.isHexValid() ?? false ? element.color : nil
        let closeButton = CrossView(lineColorHex: color, lineWidth: element.lineWidth)
        closeButton.isUserInteractionEnabled = true
        let closeRecognizer = UILongPressGestureRecognizer(target: controller, action: #selector(controller.onCloseButton))
        closeRecognizer.minimumPressDuration = 0
        closeButton.addGestureRecognizer(closeRecognizer)
        return closeButton
    }
    
    func setupConstraints(for view: UIView, from element: ContentElement, in parentView: UIView) {
        if element.size?.kind == .unknown {
            return
        }
        
        let size = element.size ?? ContentElementSize(kind: .dp, width: 24, height: 24)
        let top = element.position?.margin?.top ?? 0.02
        let right = element.position?.margin?.right ?? 0.02
        
        let horizontalOffset = (parentView.frame.width - CGFloat(size.width)) * right
        let verticalOffset = (parentView.frame.height - CGFloat(size.height)) * top
        
        if size.kind == .dp {
            view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                view.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -horizontalOffset),
                view.topAnchor.constraint(equalTo: parentView.topAnchor, constant: verticalOffset),
                view.widthAnchor.constraint(equalToConstant: CGFloat(size.width)),
                view.heightAnchor.constraint(equalToConstant: CGFloat(size.height))
            ])
        }
    }
}
