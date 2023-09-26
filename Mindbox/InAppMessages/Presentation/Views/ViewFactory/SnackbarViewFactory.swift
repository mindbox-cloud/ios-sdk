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
    
    func create(model: MindboxFormVariant, id: String, imagesDict: [String: UIImage], firstImageValue: String, onPresented: @escaping () -> Void, onTapAction: @escaping (ContentBackgroundLayerAction?) -> Void, onClose: @escaping () -> Void) -> UIViewController? {
        if case .snackbar(let snackbarFormVariant) = model {
            if let gravity = snackbarFormVariant.content.position?.gravity?.element?.vertical {
                var snackbarViewController: UIViewController?
                let snackbarView = SnackbarView(onClose: onClose)
                switch gravity {
                    case .top:
                        snackbarViewController = TopSnackbarViewController(model: snackbarFormVariant, imagesDict: imagesDict, snackbarView: snackbarView, firstImageValue: firstImageValue, onPresented: onPresented, onTapAction: onTapAction)
                    case .bottom:
                        snackbarViewController = BottomSnackbarViewController(model: snackbarFormVariant, imagesDict: imagesDict, snackbarView: snackbarView, firstImageValue: firstImageValue, onPresented: onPresented, onTapAction: onTapAction)
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
