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

    func create(with params: ViewFactoryParameters) -> UIViewController? {
        if case .snackbar(let snackbarFormVariant) = params.model {
            if let gravity = snackbarFormVariant.content.position.gravity?.vertical {
                var snackbarViewController: UIViewController?
                let snackbarView = SnackbarView(onClose: params.onClose)
                switch gravity {
                    case .top:
                    snackbarViewController = TopSnackbarViewController(model: snackbarFormVariant,
                                                                       imagesDict: params.imagesDict,
                                                                       snackbarView: snackbarView,
                                                                       firstImageValue: params.firstImageValue,
                                                                       onPresented: params.onPresented,
                                                                       onTapAction: params.onTapAction)
                    case .bottom:
                    snackbarViewController = BottomSnackbarViewController(model: snackbarFormVariant,
                                                                          imagesDict: params.imagesDict,
                                                                          snackbarView: snackbarView,
                                                                          firstImageValue: params.firstImageValue,
                                                                          onPresented: params.onPresented,
                                                                          onTapAction: params.onTapAction)
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
