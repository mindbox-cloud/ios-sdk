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
        makeInAppMessageWindow()
    }

    func present(id: String, in window: UIWindow, using viewController: UIViewController) {
        Logger.common(message: "[WebView] WebviewPresentationStrategy: Starting presentation", category: .webViewInAppMessages)
        window.rootViewController = viewController
        window.backgroundColor = .clear
        // A near-zero alpha keeps the window in the hierarchy and active, but invisible.
        // It's important for the WebView to execute JavaScript in the background.
        window.alpha = 0.00
        window.isUserInteractionEnabled = false
        window.isHidden = false
        Logger.common(message: "[WebView] WebviewPresentationStrategy: Window setup completed", category: .webViewInAppMessages)
        
        // Force view controller to load its view.
        // Start loading the WebView when it is hidden.
        // It is necessary that the window is fully initialized before making it further visible.
        _ = viewController.view
        Logger.common(message: "[WebView] WebviewPresentationStrategy: View controller view loaded", category: .webViewInAppMessages)
        
        Logger.common(message: "[WebView] In-app WebView with id \(id) start presenting with hidden window", category: .webViewInAppMessages)
    }

    func dismiss(viewController: UIViewController) {
        viewController.view.window?.isHidden = true
        viewController.view.window?.rootViewController = nil
        Logger.common(message: "[WebView] In-app WebView presentation dismissed", category: .webViewInAppMessages)
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
