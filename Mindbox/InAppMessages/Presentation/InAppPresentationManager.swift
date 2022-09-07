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
    private var inAppWindow: UIWindow?

    func present(inAppMessage: InAppMessage) {
        Log("Starting to present)")
            .category(.inAppMessages).level(.debug).make()

        let currentKeyWindow = currentKeyWindow()
        let inAppWindow = makeInAppMessageWindow()
        let inAppViewController = InAppMessageViewController()
        inAppViewController.onClose = { [currentKeyWindow, weak self] in
            self?.inAppWindow = nil
            currentKeyWindow?.makeKeyAndVisible()
        }
        inAppWindow.rootViewController = inAppViewController
        inAppWindow.makeKeyAndVisible()
    }

    private func makeInAppMessageWindow() -> UIWindow {
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

    private func currentKeyWindow() -> UIWindow? {
        if #available(iOS 13.0, *) {
            return UIApplication
                .shared
                .connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        } else {
            return UIApplication.shared.windows.first { $0.isKeyWindow }
        }
    }
}

class InAppMessageViewController: UIViewController {

    var onClose: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .red

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onCloseInAppMessage))
        view.addGestureRecognizer(tapGesture)
    }

    @objc func onCloseInAppMessage() {
        onClose?()
    }
}
