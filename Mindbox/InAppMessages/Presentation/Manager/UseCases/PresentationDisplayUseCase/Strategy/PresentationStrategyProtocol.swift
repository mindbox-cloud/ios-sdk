//
//  PresentationStrategyProtocol.swift
//  Mindbox
//
//  Created by vailence on 18.07.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import UIKit

protocol PresentationStrategyProtocol {
    var window: UIWindow? { get set }
    
    func getWindow() -> UIWindow?
    func present(id: String, in window: UIWindow, using viewController: UIViewController)
    func dismiss(viewController: UIViewController)
    func setupWindowFrame(model: MindboxFormVariant, imageSize: CGSize)
}
