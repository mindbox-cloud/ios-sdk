//
//  InAppPresentationManager.swift
//  Mindbox
//
//  Created by Максим Казаков on 06.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit

/// Prepares UI for in-app messages and shows them
final class InAppPresentationManager {

    public init(imagesStorage: InAppImagesStorage) {
        self.imagesStorage = imagesStorage
    }

    private let imagesStorage: InAppImagesStorage

    var inAppWindow: UIWindow?
    func present(inAppMessage: InAppMessage) {
        Log("Starting to present)")
            .category(.inAppMessages).level(.debug).make()

        let viewController = InAppMessageViewController()

        let inAppWindow = ensureWindow()
        inAppWindow.rootViewController = viewController
        inAppWindow.makeKeyAndVisible()
    }

    private func ensureWindow() -> UIWindow {
        if let inAppWindow = self.inAppWindow {
            return inAppWindow
        }
        let window: UIWindow
        if #available(iOS 13.0, *),
           let currentWindowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            window = UIWindow(windowScene: currentWindowScene)
        } else {
            window = UIWindow(frame: UIScreen.main.bounds)
        }
        self.inAppWindow = window
        window.windowLevel = UIWindow.Level.alert + 1
        window.isHidden = false
        return window
    }
}

class InAppMessageViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .red
    }
}
