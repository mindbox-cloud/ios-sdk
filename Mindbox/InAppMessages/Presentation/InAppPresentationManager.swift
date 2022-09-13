//
//  InAppPresentationManager.swift
//  Mindbox
//
//  Created by Максим Казаков on 06.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit

struct InAppMessageUIModel {
    let imageData: Data
}

/// Prepares UI for in-app messages and shows them
final class InAppPresentationManager {

    private var inAppWindow: UIWindow?

    func present(inAppUIModel: InAppMessageUIModel) {
        Log("Starting to present)")
            .category(.inAppMessages).level(.debug).make()

        let inAppWindow = makeInAppMessageWindow()

        let inAppViewController = InAppMessageViewController(
            inAppUIModel: inAppUIModel,
            onClose: { [weak self] in
                self?.inAppWindow?.isHidden = true
                self?.inAppWindow?.rootViewController = nil
            })
        inAppWindow.rootViewController = inAppViewController
    }

    private func makeInAppMessageWindow() -> UIWindow {
        let window: UIWindow
        if #available(iOS 13.0, *) {
            window = iOS13PlusWindow
        } else {
            window = UIWindow(frame: UIScreen.main.bounds)
        }
        self.inAppWindow = window
        window.windowLevel = UIWindow.Level.normal
        window.isHidden = false
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
    private var iOS13PlusWindow: UIWindow {
        if let foregroundedScene = foregroundedScene, foregroundedScene.delegate != nil {
            return UIWindow(windowScene: foregroundedScene)
        } else {
            return UIWindow(frame: UIScreen.main.bounds)
        }
    }
}
