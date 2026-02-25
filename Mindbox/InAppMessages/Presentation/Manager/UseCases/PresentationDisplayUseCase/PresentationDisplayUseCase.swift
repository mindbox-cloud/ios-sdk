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
    private let tracker: InAppMessagesTrackerProtocol
    private lazy var clickTracker = PresentationClickTracker(tracker: tracker)

    init(tracker: InAppMessagesTrackerProtocol) {
        self.tracker = tracker
    }

    func presentInAppUIModel(
        model: InAppFormData,
        onPresented: @escaping () -> Void,
        onTapAction: @escaping InAppMessageTapAction,
        onClose: @escaping () -> Void,
        onError: @escaping (InAppPresentationError) -> Void
    ) {

        changeType(model: model.content)

        guard let presentationStrategy = presentationStrategy else {
            onError(.failed("[PresentationDisplayUseCase] Presentation strategy is not configured."))
            return
        }

        guard let window = presentationStrategy.getWindow() else {
            Logger.common(message: "[PresentationDisplayUseCase] In-app window creating failed")
            onError(.failedToLoadWindow)
            return
        }

        guard let factory = self.factory else {
            Logger.common(message: "[PresentationDisplayUseCase] Factory does not exists.", level: .error, category: .general)
            onError(.failed("[PresentationDisplayUseCase] Factory does not exist."))
            return
        }

        let wrappedTapAction: InAppMessageTapAction
        if factory is WebViewFactory {
            wrappedTapAction = onTapAction
        } else {
            wrappedTapAction = { [weak self] url, payload in
                self?.clickTracker.trackClick(id: model.inAppId)
                onTapAction(url, payload)
            }
        }

        let parameters = ViewFactoryParameters(model: model.content,
                                               id: model.inAppId,
                                               imagesDict: model.imagesDict,
                                               firstImageValue: model.firstImageValue,
                                               onPresented: onPresented,
                                               onTapAction: wrappedTapAction,
                                               onClose: onClose,
                                               onError: onError,
                                               operation: model.operation)

        guard let viewController = factory.create(with: parameters) else {
            onError(.failed("[PresentationDisplayUseCase] Failed to create in-app view controller."))
            return
        }

        if let image = model.imagesDict[model.firstImageValue] {
            presentationStrategy.setupWindowFrame(model: model.content, imageSize: image.size)
        }

        guard presentationStrategy.present(id: model.inAppId, in: window, using: viewController) else {
            onError(.failed("[PresentationDisplayUseCase] Failed to present in-app view controller."))
            return
        }

        presentedVC = viewController
    }

    func dismissInAppUIModel(onClose: @escaping () -> Void) {
        guard let presentedVC = presentedVC else {
            return
        }
        
        presentationStrategy?.dismiss(viewController: presentedVC)
        self.presentedVC = nil
        self.model = nil
        self.presentationStrategy = nil
        self.factory = nil
        
        if let webVC = presentedVC as? WebViewController, webVC.isTimeoutClose {
            return
        }
        
        onClose()
    }

    func onPresented(id: String, _ completion: @escaping () -> Void) {
        do {
            try tracker.trackView(id: id)
            Logger.common(message: "[PresentationDisplayUseCase] Track InApp.View. Id \(id)", level: .info, category: .notification)
        } catch {
            Logger.common(message: "[PresentationDisplayUseCase] Track InApp.View failed with error: \(error)", level: .error, category: .notification)
        }
        completion()
    }

    private func changeType(model: MindboxFormVariant) {
        switch model {
            case .modal(let modalVariant):
                if modalVariant.content.background.layers.contains(where: { $0.layerType == .webview }) {
                    self.presentationStrategy = WebviewPresentationStrategy()
                    self.factory = WebViewFactory()
                } else {
                    self.presentationStrategy = ModalPresentationStrategy()
                    self.factory = ModalViewFactory()
                }
            case .snackbar:
                self.presentationStrategy = SnackbarPresentationStrategy()
                self.factory = SnackbarViewFactory()
            default:
                break
        }
    }
}
