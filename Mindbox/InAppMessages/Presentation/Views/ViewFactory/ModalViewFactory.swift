//
//  ModalViewFactory.swift
//  Mindbox
//
//  Created by vailence on 18.07.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import UIKit

class ModalViewFactory: ViewFactoryProtocol {

    weak var myViewController: UIViewController?

    func create(with params: ViewFactoryParameters) -> UIViewController? {
        if case .modal(let modalFormVariant) = params.model {
            let viewController = ModalViewController(model: modalFormVariant,
                                                     id: params.id,
                                                     imagesDict: params.imagesDict,
                                                     onPresented: params.onPresented,
                                                     onTapAction: params.onTapAction,
                                                     onClose: params.onClose)
            myViewController = viewController
            return viewController
        }

        return nil
    }
}
