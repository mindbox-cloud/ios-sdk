//
//  LayerFactory.swift
//  Mindbox
//
//  Created by vailence on 04.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import UIKit

protocol LayerFactory {
    func create(from image: UIImage, layer: ContentBackgroundLayer, in view: UIView, with controller: GestureHandler) -> UIView?
    func setupConstraints(for view: UIView, in parentView: UIView)
    func setupConstraintsSnackbar(for view: UIView, in parentView: UIView)
}
