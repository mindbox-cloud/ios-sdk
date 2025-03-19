//
//  ModalPresentationStrategy.swift
//  Mindbox
//
//  Created by Egor Kitselyuk on 19.03.2025.
//

import UIKit
import MindboxLogger

final class WebviewPresentationStrategy: PresentationStrategyProtocol {
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
            window = nil
        }
        self.window = window
        window?.windowLevel = .normal + 3
        window?.isHidden = false
        return window
    }

    @available(iOS 13.0, *)
    private var mostSuitableScene: UIWindowScene? {
        for connectedScene in UIApplication.shared.connectedScenes {
            if let windowScene = connectedScene as? UIWindowScene, connectedScene.activationState == .foregroundActive {
                return windowScene
            }
        }

        return UIApplication.shared.connectedScenes.first as? UIWindowScene
    }

    @available(iOS 13.0, *)
    private var iOS13PlusWindow: UIWindow? {
        if let mostSuitableScene = mostSuitableScene {
            return UIWindow(windowScene: mostSuitableScene)
        } else {
            return nil
        }
    }
}
