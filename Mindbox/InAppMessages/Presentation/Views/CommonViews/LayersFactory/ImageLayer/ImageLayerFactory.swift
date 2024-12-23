//
//  ImageLayerFactory.swift
//  Mindbox
//
//  Created by vailence on 17.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

class ImageLayerFactory: LayerFactory {
    func create(from image: UIImage, layer: ContentBackgroundLayer, in view: UIView, with controller: GestureHandler) -> UIView? {
        if case .image(let imageContentBackgroundLayer) = layer {
            let inAppView = InAppImageOnlyView(image: image, action: imageContentBackgroundLayer.action)
            let imageTapGestureRecognizer = UITapGestureRecognizer(target: controller, action: #selector(controller.imageTapped(_:)))
            inAppView.addGestureRecognizer(imageTapGestureRecognizer)
            return inAppView
        }

        Logger.common(message: "ImageLayerFactory return nil.")
        return nil
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

    func setupConstraintsSnackbar(for view: UIView, in parentView: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: parentView.topAnchor),
            view.bottomAnchor.constraint(equalTo: parentView.bottomAnchor),
            view.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: parentView.trailingAnchor)
        ])
    }
}
