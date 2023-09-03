//
//  SnackbarViewFactory.swift
//  Mindbox
//
//  Created by vailence on 15.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import UIKit

class SnackbarViewFactory: ViewFactoryProtocol {

    weak var viewController: UIViewController?
    
    func create(model: MindboxFormVariant, id: String, imagesDict: [String: UIImage], onPresented: @escaping () -> Void, onTapAction: @escaping (ContentBackgroundLayerAction?) -> Void, onClose: @escaping () -> Void) -> UIViewController? {
        if case .snackbar(let snackbarFormVariant) = model {
            if let gravity = snackbarFormVariant.content.position?.gravity?.element?.vertical {
                var snackbarViewController: UIViewController?
                switch gravity {
                    case .top:
                        snackbarViewController = TopSnackbarViewController(model: snackbarFormVariant, id: id, imagesDict: imagesDict, onPresented: onPresented, onTapAction: onTapAction, onClose: onClose)
                    case .bottom:
                        snackbarViewController = BottomSnackbarViewController(model: snackbarFormVariant, id: id, imagesDict: imagesDict, onPresented: onPresented, onTapAction: onTapAction, onClose: onClose)
                    default:
                        return nil
                }
                
                self.viewController = snackbarViewController
                return viewController
            }
        }

        return nil
    }
}
