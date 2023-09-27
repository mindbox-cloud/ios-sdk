//
//  SnackbarViewFactory.swift
//  Mindbox
//
//  Created by vailence on 15.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import UIKit
import MindboxLogger

class SnackbarViewFactory: ViewFactoryProtocol {

    weak var viewController: UIViewController?
    
    func create(model: MindboxFormVariant, id: String, imagesDict: [String: UIImage], firstImageValue: String, onPresented: @escaping () -> Void, onTapAction: @escaping (ContentBackgroundLayerAction?) -> Void, onClose: @escaping () -> Void) -> UIViewController? {
        if case .snackbar(let snackbarFormVariant) = model {
            if let gravity = snackbarFormVariant.content.position.gravity?.vertical {
                var snackbarViewController: UIViewController?
                let snackbarView = SnackbarView(onClose: onClose)
                switch gravity {
                    case .top:
                        Logger.common(message: "SnackbarViewFactory TopSnackbarViewController handleSwipeGesture created.")
                        snackbarViewController = TopSnackbarViewController(model: snackbarFormVariant, imagesDict: imagesDict, snackbarView: snackbarView, firstImageValue: firstImageValue, onPresented: onPresented, onTapAction: onTapAction)
                    case .bottom:
                        Logger.common(message: "SnackbarViewFactory BottomSnackbarViewController handleSwipeGesture created.")
                        snackbarViewController = BottomSnackbarViewController(model: snackbarFormVariant, imagesDict: imagesDict, snackbarView: snackbarView, firstImageValue: firstImageValue, onPresented: onPresented, onTapAction: onTapAction)
                    default:
                        Logger.common(message: "SnackbarViewFactory controller is nil.")
                        return nil
                }
                
                self.viewController = snackbarViewController
                
                return viewController
            }
        }
        
        Logger.common(message: "SnackbarViewFactory create returns nil.")
        return nil
    }
}
