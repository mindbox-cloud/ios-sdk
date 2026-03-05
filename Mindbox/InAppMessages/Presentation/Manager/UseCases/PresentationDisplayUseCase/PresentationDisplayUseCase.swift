//
//  PresentationDisplayUseCase.swift
//  Mindbox
//
//  Created by vailence on 18.07.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

protocol PresentationDisplayUseCaseProtocol: AnyObject {
    func presentInAppUIModel(
        model: InAppFormData,
        onPresented: @escaping () -> Void,
        onTapAction: @escaping InAppMessageTapAction,
        onClose: @escaping () -> Void,
        onError: @escaping (InAppPresentationError) -> Void
    )
    func dismissInAppUIModel(onClose: @escaping () -> Void)
    func onPresented(id: String, _ completion: @escaping () -> Void)
}

final class PresentationDisplayUseCase: PresentationDisplayUseCaseProtocol {
    typealias DependenciesResolver = (MindboxFormVariant) -> (
        strategy: PresentationStrategyProtocol?,
        factory: ViewFactoryProtocol?
    )

    private var presentationStrategy: PresentationStrategyProtocol?
    private var presentedVC: UIViewController?
    private var model: InAppFormData?
    private var factory: ViewFactoryProtocol?
    private let tracker: InAppMessagesTrackerProtocol
    private let dependenciesResolver: DependenciesResolver
    private lazy var clickTracker = PresentationClickTracker(tracker: tracker)

    init(
        tracker: InAppMessagesTrackerProtocol,
        dependenciesResolver: @escaping DependenciesResolver = PresentationDisplayUseCase.defaultDependenciesResolver
    ) {
        self.tracker = tracker
        self.dependenciesResolver = dependenciesResolver
    }

    func presentInAppUIModel(
        model: InAppFormData,
        onPresented: @escaping () -> Void,
        onTapAction: @escaping InAppMessageTapAction,
        onClose: @escaping () -> Void,
        onError: @escaping (InAppPresentationError) -> Void
    ) {

        let dependencies = dependenciesResolver(model.content)
        presentationStrategy = dependencies.strategy
        factory = dependencies.factory

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
        Logger.common(message: "[PresentationDisplayUseCase] InApp presented. Id \(id)", level: .info, category: .notification)
        completion()
    }
}

private extension PresentationDisplayUseCase {
    static func defaultDependenciesResolver(model: MindboxFormVariant) -> (
        strategy: PresentationStrategyProtocol?,
        factory: ViewFactoryProtocol?
    ) {
        switch model {
        case .modal(let modalVariant):
            if modalVariant.content.background.layers.contains(where: { $0.layerType == .webview }) {
                return (strategy: WebviewPresentationStrategy(), factory: WebViewFactory())
            }
            return (strategy: ModalPresentationStrategy(), factory: ModalViewFactory())
        case .snackbar:
            return (strategy: SnackbarPresentationStrategy(), factory: SnackbarViewFactory())
        default:
            return (strategy: nil, factory: nil)
        }
    }
}
