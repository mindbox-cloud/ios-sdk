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

protocol InAppPresentationManagerProtocol: AnyObject {
    func present(inAppFormData: InAppFormData, onPresentationCompleted: @escaping (InAppPresentationError?) -> Void)
}

enum InAppPresentationError {
    case failedToLoadImages
}

/// Prepares UI for in-app messages and shows them
final class InAppPresentationManager: InAppPresentationManagerProtocol {

    init(imagesStorage: InAppImagesStorageProtocol) {
        self.imagesStorage = imagesStorage
    }

    private let imagesStorage: InAppImagesStorageProtocol
    private var inAppWindow: UIWindow?

    func present(inAppFormData: InAppFormData, onPresentationCompleted: @escaping (InAppPresentationError?) -> Void) {
        imagesStorage.getImage(url: inAppFormData.imageUrl, completionQueue: .main) { imageData in
            guard let inAppUIModel = imageData.map(InAppMessageUIModel.init) else {
                onPresentationCompleted(.failedToLoadImages)
                return
            }
            self.presentInAppUIModel(inAppUIModel: inAppUIModel, onPresentationCompleted: onPresentationCompleted)
        }
    }

    // MARK: - Private

    private func presentInAppUIModel(inAppUIModel: InAppMessageUIModel, onPresentationCompleted: @escaping (InAppPresentationError?) -> Void) {
        Log("Starting to present)")
            .category(.inAppMessages).level(.debug).make()

        let inAppWindow = makeInAppMessageWindow()

        let inAppViewController = InAppMessageViewController(
            inAppUIModel: inAppUIModel,
            onClose: { [weak self] in
                self?.inAppWindow?.isHidden = true
                self?.inAppWindow?.rootViewController = nil
                onPresentationCompleted(nil)
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
