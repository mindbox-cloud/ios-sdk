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
        window.isHidden = true
        Logger.common(message: "[WebView] WebviewPresentationStrategy: Window setup completed", category: .webViewInAppMessages)
        
        // Force view controller to load its view
        _ = viewController.view
        Logger.common(message: "[WebView] WebviewPresentationStrategy: View controller view loaded", category: .webViewInAppMessages)
        
        Logger.common(message: "[WebView] In-app WebView with id \(id) start presenting with hidden window", category: .webViewInAppMessages)
    }

    func dismiss(viewController: UIViewController) {
        viewController.view.window?.isHidden = true
        viewController.view.window?.rootViewController = nil
        window = nil
        Logger.common(message: "[WebView] In-app WebView presentation dismissed", category: .webViewInAppMessages)
    }

    func setupWindowFrame(model: MindboxFormVariant, imageSize: CGSize) {
        // Not need to setup.
    }

    private func makeInAppMessageWindow() -> UIWindow? {
        Logger.common(message: "[WebView] WebviewPresentationStrategy: Creating window", category: .webViewInAppMessages)
        let window: UIWindow?
        if #available(iOS 13.0, *) {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                Logger.common(message: "[WebView] WebviewPresentationStrategy: Found scene", category: .webViewInAppMessages)
                window = UIWindow(windowScene: scene)
                window?.frame = UIScreen.main.bounds
                window?.backgroundColor = .clear
                window?.isHidden = true
                Logger.common(message: "[WebView] WebviewPresentationStrategy: Window created with scene", category: .webViewInAppMessages)
            } else {
                Logger.common(message: "[WebView] WebviewPresentationStrategy: No scene found", level: .error, category: .webViewInAppMessages)
                window = nil
            }
        } else {
            Logger.common(message: "[WebView] WebviewPresentationStrategy: iOS < 13, creating window without scene", category: .webViewInAppMessages)
            window = UIWindow(frame: UIScreen.main.bounds)
            window?.backgroundColor = .clear
            window?.isHidden = true
        }
        self.window = window
        Logger.common(message: "[WebView] WebviewPresentationStrategy: Window setup completed", category: .webViewInAppMessages)
        return window
    }
}
