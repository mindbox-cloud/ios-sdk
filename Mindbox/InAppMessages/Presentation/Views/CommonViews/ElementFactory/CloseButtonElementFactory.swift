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
        
        if case .closeButton(let closeButtonElement) = element {
            let color = closeButtonElement.color?.isHexValid() ?? false ? closeButtonElement.color : nil
            let closeButton = CrossView(lineColorHex: color, lineWidth: closeButtonElement.lineWidth)
            closeButton.isUserInteractionEnabled = true
            let closeRecognizer = UILongPressGestureRecognizer(target: controller, action: #selector(controller.onCloseButton))
            closeRecognizer.minimumPressDuration = 0
            closeButton.addGestureRecognizer(closeRecognizer)
            return closeButton
        }
        
        return nil
    }
    
    func setupConstraints(for view: UIView, from element: ContentElement, in parentView: UIView) {
        if case .closeButton(let closeButtonElement) = element {
            let size = closeButtonElement.size?.element ?? ContentElementSize(kind: .dp, width: 24, height: 24)
            let top = closeButtonElement.position?.margin?.element?.top ?? 0.02
            let right = closeButtonElement.position?.margin?.element?.right ?? 0.02
            
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
}
