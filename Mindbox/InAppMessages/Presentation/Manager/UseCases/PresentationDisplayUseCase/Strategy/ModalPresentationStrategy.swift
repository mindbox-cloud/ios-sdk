//
//  ModalPresentationStrategy.swift
//  Mindbox
//
//  Created by vailence on 18.07.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

final class ModalPresentationStrategy: PresentationStrategyProtocol {
    var window: UIWindow?
    
    func getWindow() -> UIWindow? {
        return makeInAppMessageWindow()
    }
    
    func present(id: String, in window: UIWindow, using viewController: UIViewController) {
        window.rootViewController = viewController
        window.isHidden = false
        Logger.common(message: "In-app modal with id \(id) presented", level: .info, category: .inAppMessages)
    }

    func dismiss(viewController: UIViewController) {
        viewController.view.window?.isHidden = true
        viewController.view.window?.rootViewController = nil
        Logger.common(message: "In-app modal presentation dismissed", level: .debug, category: .inAppMessages)
    }
    
    func setupWindowFrame(model: MindboxFormVariant, imageSize: CGSize) {
        // Not need to setup. 
    }
    
    private func makeInAppMessageWindow() -> UIWindow? {
        let window: UIWindow?
        if #available(iOS 13.0, *) {
            window = iOS13PlusWindow
        } else {
            window = UIWindow(frame: UIScreen.main.bounds)
        }
        self.window = window
        window?.windowLevel = .alert
        window?.isHidden = false
        return window
    }

    @available(iOS 13.0, *)
    private var foregroundedScene: UIWindowScene? {
        for connectedScene in UIApplication.shared.connectedScenes {
            if let windowScene = connectedScene as? UIWindowScene, connectedScene.activationState == .foregroundActive {
                return windowScene
            }
        }
    
        return nil
    }

    @available(iOS 13.0, *)
    private var iOS13PlusWindow: UIWindow? {
        if let foregroundedScene = foregroundedScene {
            return UIWindow(windowScene: foregroundedScene)
        } else {
            return UIWindow(frame: UIScreen.main.bounds)
        }
    }
}
