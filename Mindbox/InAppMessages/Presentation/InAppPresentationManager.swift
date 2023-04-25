//
//  InAppPresentationManager.swift
//  Mindbox
//
//  Created by Максим Казаков on 06.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit
import MindboxLogger

struct InAppMessageUIModel {
    struct InAppRedirect {
        let redirectUrl: URL?
        let payload: String
    }
    let inAppId: String
    let imageData: Data
    let redirect: InAppRedirect
}

protocol InAppPresentationManagerProtocol: AnyObject {
    func present(
        inAppFormData: InAppFormData,
        onPresented: @escaping () -> Void,
        onTapAction: @escaping InAppMessageTapAction,
        onPresentationCompleted: @escaping () -> Void,
        onError: @escaping (InAppPresentationError) -> Void
    )
}

enum InAppPresentationError {
    case failedToLoadImages
    case failedToLoadWindow
}

typealias InAppMessageTapAction = (_ tapLink: URL?, _ payload: String) -> Void

/// Prepares UI for in-app messages and shows them
final class InAppPresentationManager: InAppPresentationManagerProtocol {

    init(
        imagesStorage: InAppImagesStorageProtocol,
        inAppTracker: InAppMessagesTrackerProtocol
    ) {
        self.imagesStorage = imagesStorage
        self.inAppTracker = inAppTracker
    }

    private let imagesStorage: InAppImagesStorageProtocol
    private let inAppTracker: InAppMessagesTrackerProtocol
    private var inAppWindow: UIWindow?

    func present(
        inAppFormData: InAppFormData,
        onPresented: @escaping () -> Void,
        onTapAction: @escaping InAppMessageTapAction,
        onPresentationCompleted: @escaping () -> Void,
        onError: @escaping (InAppPresentationError) -> Void
    ) {
        clickTracked = false
        imagesStorage.getImage(url: inAppFormData.imageUrl, completionQueue: .main) { imageData in
            if let imageData = imageData {
                let redirectInfo = InAppMessageUIModel.InAppRedirect(
                    redirectUrl: URL(string: inAppFormData.redirectUrl),
                    payload: inAppFormData.intentPayload
                )

                let inAppUIModel = InAppMessageUIModel(
                    inAppId: inAppFormData.inAppId,
                    imageData: imageData,
                    redirect: redirectInfo
                )
                self.presentInAppUIModel(
                    inAppUIModel: inAppUIModel,
                    onPresented: onPresented,
                    onTapAction: onTapAction,
                    onPresentationCompleted: onPresentationCompleted,
                    onError: onError
                )
            } else {
                onError(.failedToLoadImages)
                return
            }
        }
    }

    // MARK: - Private

    private func presentInAppUIModel(
        inAppUIModel: InAppMessageUIModel,
        onPresented: @escaping () -> Void,
        onTapAction: @escaping InAppMessageTapAction,
        onPresentationCompleted: @escaping () -> Void,
        onError: @escaping (InAppPresentationError) -> Void
    ) {
        Logger.common(message: "PresentInAppUIModel Started")
        Logger.common(message: "Trying to create InappWindow")
        guard let inAppWindow = makeInAppMessageWindow() else {
            Logger.common(message: "InappWindow creating failed")
            onError(.failedToLoadWindow)
            return
        }
        
        Logger.common(message: "InappWindow created Successfully")

        let close: () -> Void = { [weak self] in
            self?.onClose(inApp: inAppUIModel, onPresentationCompleted)
        }
        let inAppViewController = InAppMessageViewController(
            inAppUIModel: inAppUIModel,
            onPresented: { [weak self] in
                self?.onPresented(inApp: inAppUIModel, onPresented)
            },
            onTapAction: { [weak self] in
                self?.onTapAction(inApp: inAppUIModel, onTap: onTapAction, close: close)
            },
            onClose: close
        )
        inAppWindow.rootViewController = inAppViewController
        Logger.common(message: "In-app with id \(inAppUIModel.inAppId) presented", level: .info, category: .inAppMessages)
    }

    private func onPresented(inApp: InAppMessageUIModel, _ completion: @escaping () -> Void) {
        do {
            try inAppTracker.trackView(id: inApp.inAppId)
            Logger.common(message: "Track InApp.View. Id \(inApp.inAppId)", level: .info, category: .notification)
        } catch {
            Logger.common(message: "Track InApp.View failed with error: \(error)", level: .error, category: .notification)
        }
        completion()
    }

    private var clickTracked = false
    private func onTapAction(
        inApp: InAppMessageUIModel,
        onTap: @escaping InAppMessageTapAction,
        close: @escaping () -> Void
    ) {
        Logger.common(message: "InApp presentation completed", level: .debug, category: .inAppMessages)
        if !clickTracked {
            do {
                try inAppTracker.trackClick(id: inApp.inAppId)
                clickTracked = true
                Logger.common(message: "Track InApp.Click. Id \(inApp.inAppId)", level: .info, category: .notification)
            } catch {
                Logger.common(message: "Track InApp.Click failed with error: \(error)", level: .error, category: .notification)
            }
        }

        let redirect = inApp.redirect
        if redirect.redirectUrl != nil || !redirect.payload.isEmpty {
            onTap(redirect.redirectUrl, redirect.payload)
            close()
        }
    }

    private func onClose(inApp: InAppMessageUIModel, _ completion: @escaping () -> Void) {
        Logger.common(message: "InApp presentation dismissed", level: .debug, category: .inAppMessages)
        inAppWindow?.isHidden = true
        inAppWindow?.rootViewController = nil
        completion()
    }

    private func makeInAppMessageWindow() -> UIWindow? {
        let window: UIWindow?
        if #available(iOS 13.0, *) {
            Logger.common(message: "Window available iOS 13")
            window = iOS13PlusWindow
        } else {
            Logger.common(message: "Window NOT available iOS 13")
            Logger.common(message: "Bounds: \(UIScreen.main.bounds)")
            window = UIWindow(frame: UIScreen.main.bounds)
        }
        self.inAppWindow = window
        window?.windowLevel = UIWindow.Level.normal
        window?.isHidden = false
        
        Logger.common(message: "makeInAppMessageWindow window is nil: \(window == nil)")
        return window
    }

    @available(iOS 13.0, *)
    private var foregroundedScene: UIWindowScene? {
        for connectedScene in UIApplication.shared.connectedScenes {
            Logger.common(message: "ConnectedScene - \(connectedScene)")
            if let windowScene = connectedScene as? UIWindowScene, connectedScene.activationState == .foregroundActive {
                Logger.common(message: "ForegroundedScene is ready to use")
                return windowScene
            }
        }
        
        Logger.common(message: "foregroundedScene is NIL")
        return nil
    }

    @available(iOS 13.0, *)
    private var iOS13PlusWindow: UIWindow? {
        Logger.common(message: "ForegroundDelegate - \(foregroundedScene?.delegate)")
        if let foregroundedScene = foregroundedScene {
            return UIWindow(windowScene: foregroundedScene)
        } else {
            Logger.common(message: "iOS13PlusWindow return nil")
            return nil
        }
    }
}
