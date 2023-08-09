//
//  PresentationDisplayUseCase.swift
//  Mindbox
//
//  Created by vailence on 18.07.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

final class PresentationDisplayUseCase {

    private var presentationStrategy: PresentationStrategyProtocol?
    private var presentedVC: UIViewController?
    private var viewFactory: ViewFactoryProtocol?
    private var model: InAppFormData?

    func presentInAppUIModel(inAppUIModel: InAppFormData, onPresented: @escaping () -> Void, onTapAction: @escaping (ContentBackgroundLayerAction?) -> Void, onClose: @escaping () -> Void) {
        guard let window = presentationStrategy?.getWindow() else {
            Logger.common(message: "In-app modal window creating failed")
            return
        }
        
        model = inAppUIModel
        guard let viewController = viewFactory?.create(inAppUIModel: inAppUIModel,
                                                       onPresented: onPresented,
                                                       onTapAction: onTapAction,
                                                       onClose: onClose) else {
            return
        }
        
        presentedVC = viewController
        presentationStrategy?.present(id: inAppUIModel.inAppId, in: window, using: viewController)
    }

    func dismissInAppUIModel(onClose: @escaping () -> Void) {
        guard let presentedVC = presentedVC else {
            return
        }
        presentationStrategy?.dismiss(viewController: presentedVC)
        onClose()
        self.viewFactory = nil
        self.presentedVC = nil
        self.model = nil
    }
    
    func changeType(type: ViewPresentationType) {
        switch type {
        case .modal:
            self.presentationStrategy = ModalPresentationStrategy()
            self.viewFactory = ModalViewFactory()
        default:
            return
        }
    }
}
