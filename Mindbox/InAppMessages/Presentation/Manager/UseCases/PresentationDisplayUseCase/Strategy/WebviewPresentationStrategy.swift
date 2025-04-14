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
        print("WebviewPresentationStrategy: Starting presentation")
        window.rootViewController = viewController
        window.isHidden = true
        print("WebviewPresentationStrategy: Window setup completed")
        
        // Force view controller to load its view
        _ = viewController.view
        print("WebviewPresentationStrategy: View controller view loaded")
        
        Logger.common(message: "In-app modal with id \(id) presented", level: .info, category: .inAppMessages)
        print("WebviewPresentationStrategy: Presentation completed")
    }

    func dismiss(viewController: UIViewController) {
        viewController.view.window?.isHidden = true
        viewController.view.window?.rootViewController = nil
        window = nil
        Logger.common(message: "In-app modal presentation dismissed", level: .debug, category: .inAppMessages)
    }

    func setupWindowFrame(model: MindboxFormVariant, imageSize: CGSize) {
        // Not need to setup.
    }

    private func makeInAppMessageWindow() -> UIWindow? {
        print("WebviewPresentationStrategy: Creating window")
        let window: UIWindow?
        if #available(iOS 13.0, *) {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                print("WebviewPresentationStrategy: Found scene")
                window = UIWindow(windowScene: scene)
                window?.frame = UIScreen.main.bounds
                window?.backgroundColor = .clear
                window?.isHidden = true
                print("WebviewPresentationStrategy: Window created with scene")
            } else {
                print("WebviewPresentationStrategy: No scene found")
                window = nil
            }
        } else {
            print("WebviewPresentationStrategy: iOS < 13, creating window without scene")
            window = UIWindow(frame: UIScreen.main.bounds)
            window?.backgroundColor = .clear
            window?.isHidden = true
        }
        self.window = window
        print("WebviewPresentationStrategy: Window setup completed")
        return window
    }
}
