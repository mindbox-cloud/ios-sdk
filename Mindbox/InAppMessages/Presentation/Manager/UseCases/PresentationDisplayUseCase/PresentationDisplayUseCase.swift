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
    private var model: InAppFormData?
    private var factory: ViewFactoryProtocol?
    private var tracker: InAppMessagesTrackerProtocol
    
    init(tracker: InAppMessagesTrackerProtocol) {
        self.tracker = tracker
    }

    func presentInAppUIModel(model: InAppFormData, onPresented: @escaping () -> Void, onTapAction: @escaping (ContentBackgroundLayerAction?) -> Void, onClose: @escaping () -> Void) {
        guard let window = presentationStrategy?.getWindow() else {
            Logger.common(message: "In-app modal window creating failed")
            return
        }
        
        guard let factory = self.factory else {
            Logger.common(message: "Factory does not exists.", level: .error, category: .general)
            return
        }
        
        guard let viewController = factory.create(model: model.content,
                                                  id: model.inAppId,
                                                  image: model.image,
                                                  onPresented: onPresented,
                                                  onTapAction: onTapAction,
                                                  onClose: onClose) else {
            return
        }
        
        presentedVC = viewController
        presentationStrategy?.present(id: model.inAppId, in: window, using: viewController)
    }

    func dismissInAppUIModel(onClose: @escaping () -> Void) {
        guard let presentedVC = presentedVC else {
            return
        }
        presentationStrategy?.dismiss(viewController: presentedVC)
        onClose()
        self.presentedVC = nil
        self.model = nil
    }
    
    func onPresented(id: String, _ completion: @escaping () -> Void) {
        do {
            try tracker.trackView(id: id)
            Logger.common(message: "Track InApp.View. Id \(id)", level: .info, category: .notification)
        } catch {
            Logger.common(message: "Track InApp.View failed with error: \(error)", level: .error, category: .notification)
        }
        completion()
    }
    
    func changeType(model: MindboxFormVariant) {
        switch model {
            case .modal:
                self.presentationStrategy = ModalPresentationStrategy()
                self.factory = ModalViewFactory()
            case .snackbar:
                self.presentationStrategy = SnackbarPresentationStrategy()
                self.factory = SnackbarViewFactory()
            default:
                break
        }
    }
}
