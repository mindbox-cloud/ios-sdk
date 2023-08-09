//
//  LayerFactory.swift
//  Mindbox
//
//  Created by vailence on 04.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import UIKit

protocol LayerFactory {
    func create(from image: UIImage, action: ContentBackgroundLayerAction?, in view: UIView, with controller: ModalViewController) -> UIView?
    func setupConstraints(for view: UIView, in parentView: UIView)
}

class ImageLayerFactory: LayerFactory {
    func create(from image: UIImage, action: ContentBackgroundLayerAction?, in view: UIView, with controller: ModalViewController) -> UIView? {
        let inAppView = InAppImageOnlyView(image: image, action: action)
        let imageTapGestureRecognizer = UITapGestureRecognizer(target: controller, action: #selector(controller.imageTapped(_:)))
        inAppView.addGestureRecognizer(imageTapGestureRecognizer)
        return inAppView
    }
    
    func setupConstraints(for view: UIView, in parentView: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: parentView.leadingAnchor, constant: 20),
            view.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -20),
            view.centerYAnchor.constraint(equalTo: parentView.centerYAnchor),
            view.widthAnchor.constraint(equalTo: view.heightAnchor, multiplier: 3 / 4)
        ])
    }
}
