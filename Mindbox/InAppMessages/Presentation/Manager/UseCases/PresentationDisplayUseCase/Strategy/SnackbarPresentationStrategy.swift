//
//  SnackbarPresentationStrategy.swift
//  Mindbox
//
//  Created by vailence on 16.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

final class SnackbarPresentationStrategy: PresentationStrategyProtocol {
    func getWindow() -> UIWindow? {
        return UIApplication.shared.windows.first(where: { $0.isKeyWindow })
    }
    
    func present(id: String, in window: UIWindow, using viewController: UIViewController) {
        window.rootViewController?.addChild(viewController)
        window.rootViewController?.view.addSubview(viewController.view)
        Logger.common(message: "In-app with id \(id) presented", level: .info, category: .inAppMessages)
    }

    func dismiss(viewController: UIViewController) {
        viewController.view.removeFromSuperview()
        viewController.removeFromParent()
        Logger.common(message: "InApp presentation dismissed", level: .debug, category: .inAppMessages)
    }
}
