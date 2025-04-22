//
//  ModalViewFactory.swift
//  Mindbox
//
//  Created by Egor Kitselyuk on 19.03.2025.
//

import UIKit

class WebViewFactory: ViewFactoryProtocol {

    weak var myViewController: UIViewController?

    func create(with params: ViewFactoryParameters) -> UIViewController? {
        if case .webview(let modalFormVariant) = params.model {
            let viewController = WebViewController(model: modalFormVariant,
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
