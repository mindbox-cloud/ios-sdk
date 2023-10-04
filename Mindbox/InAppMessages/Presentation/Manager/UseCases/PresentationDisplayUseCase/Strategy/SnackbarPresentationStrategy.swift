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
    
    enum Constants {
        static let oneThirdScreenHeight: CGFloat = UIScreen.main.bounds.height / 3.0
    }
    
    var window: UIWindow?
    
    func getWindow() -> UIWindow? {
        let window: UIWindow
        let screenBounds = UIScreen.main.bounds
        let windowFrame = CGRect(x: 0, y: 0, width: screenBounds.width, height: screenBounds.height)
        Logger.common(message: "SnackbarPresentationStrategy getWindow started.")
        if #available(iOS 13, *) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                window = UIWindow(windowScene: windowScene)
            } else {
                window = UIWindow(frame: UIScreen.main.bounds)
            }
        } else {
            window = UIWindow(frame: UIScreen.main.bounds)
        }
        
        window.frame = windowFrame
        window.backgroundColor = .clear
        window.windowLevel = .normal + 3
        let viewController = UIViewController()
        window.rootViewController = viewController
        viewController.view.frame = windowFrame
        window.isHidden = false
        self.window = window
        return window
    }

    func present(id: String, in window: UIWindow, using viewController: UIViewController) {
        if var topController = window.rootViewController {
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }

            viewController.view.frame = topController.view.frame
            topController.addChild(viewController)
            topController.view.addSubview(viewController.view)
            
            viewController.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                viewController.view.topAnchor.constraint(equalTo: topController.view.topAnchor),
                viewController.view.bottomAnchor.constraint(equalTo: topController.view.bottomAnchor),
                viewController.view.leadingAnchor.constraint(equalTo: topController.view.leadingAnchor),
                viewController.view.trailingAnchor.constraint(equalTo: topController.view.trailingAnchor)
            ])
            
            viewController.didMove(toParent: topController)
            Logger.common(message: "In-app snackbar with id \(id) presented", level: .info, category: .inAppMessages)
        } else {
            Logger.common(message: "Unable to get top controller. Abort.", level: .error, category: .inAppMessages)
        }
    }

    func dismiss(viewController: UIViewController) {
        viewController.view.removeFromSuperview()
        viewController.removeFromParent()
        Logger.common(message: "In-app snackbar presentation dismissed", level: .debug, category: .inAppMessages)
    }
    
    func setupWindowFrame(model: MindboxFormVariant, imageSize: CGSize) {
        switch model {
            case .snackbar(let snackbarFormVariant):
                if let gravity = snackbarFormVariant.content.position?.gravity?.element?.vertical {
                    let leftOffset = snackbarFormVariant.content.position?.margin?.element?.left ?? 0
                    let rightOffset = snackbarFormVariant.content.position?.margin?.element?.right ?? 0
                    let width = UIScreen.main.bounds.width - leftOffset - rightOffset
                    let heightMultiplier = width / imageSize.width
                    let imageHeight = imageSize.height * heightMultiplier
                    let finalHeight = (imageHeight < Constants.oneThirdScreenHeight) ? imageHeight : Constants.oneThirdScreenHeight
                    let safeAreaInset = getSafeAreaInset(gravity: gravity)
                    let y = getYPosition(gravity: gravity, finalHeight: finalHeight, safeAreaInset: safeAreaInset)
                    self.window?.frame = CGRect(x: leftOffset, y: y, width: width, height: finalHeight)
                }
            default:
                break
        }
    }
}

private extension SnackbarPresentationStrategy {
    func getSafeAreaInset(gravity: ContentPositionGravity.VerticalType) -> CGFloat {
        var safeAreaInset: CGFloat = 0
        if #available(iOS 11, *) {
            if gravity == .bottom {
                safeAreaInset = window?.safeAreaInsets.bottom ?? 0
            } else if gravity == .top {
                safeAreaInset = window?.safeAreaInsets.top ?? 0
            }
        }

        return safeAreaInset
    }
    
    func getYPosition(gravity: ContentPositionGravity.VerticalType, finalHeight: CGFloat, safeAreaInset: CGFloat) -> CGFloat {
        var y = UIScreen.main.bounds.height - finalHeight
        if gravity == .bottom {
            y = UIScreen.main.bounds.height - finalHeight - safeAreaInset
        } else if gravity == .top {
            y = safeAreaInset
        }
        
        return y
    }
}
