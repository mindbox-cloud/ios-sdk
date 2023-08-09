//
//  ModalViewFactory.swift
//  Mindbox
//
//  Created by vailence on 18.07.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import UIKit

class ModalViewFactory: ViewFactoryProtocol {

    var myViewController: UIViewController?
    
    func create(inAppUIModel: InAppFormData,
                onPresented: @escaping () -> Void,
                onTapAction: @escaping (ContentBackgroundLayerAction?) -> Void,
                onClose: @escaping () -> Void) -> UIViewController {
        let viewController = ModalViewController(inAppUIModel: inAppUIModel,
                                                        onPresented: onPresented,
                                                        onTapAction: onTapAction,
                                                        onClose: onClose)
        myViewController = viewController
        return viewController
    }
}
