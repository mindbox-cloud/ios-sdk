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
        Logger.common(message: "SnackbarPresentationStrategy getWindow started.")
        if #available(iOS 13, *) {
            let window = UIApplication.shared.connectedScenes
                .filter { $0.activationState == .foregroundActive }
                .compactMap { $0 as? UIWindowScene }
                .first?.windows
                .first(where: { $0.isKeyWindow })

            Logger.common(message: "SnackbarPresentationStrategy window iOS 13+: \(window).")
            return window
        } else {
            let window = UIApplication.shared.keyWindow
            Logger.common(message: "SnackbarPresentationStrategy window iOS 12 or less: \(window).")
            return window
        }
    }

    func present(id: String, in window: UIWindow, using viewController: UIViewController) {
        if var topController = window.rootViewController {
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
                Logger.common(message: "SnackbarPresentationStrategy topController equal = \(topController).")
            }

            topController.view.addSubview(viewController.view)
            Logger.common(message: "In-app with id \(id) presented", level: .info, category: .inAppMessages)
        } else {
            Logger.common(message: "Unable to get top controller. Abort.", level: .error, category: .inAppMessages)
        }
    }

    func dismiss(viewController: UIViewController) {
        viewController.view.removeFromSuperview()
        viewController.removeFromParent()
        Logger.common(message: "InApp presentation dismissed", level: .debug, category: .inAppMessages)
    }
}
