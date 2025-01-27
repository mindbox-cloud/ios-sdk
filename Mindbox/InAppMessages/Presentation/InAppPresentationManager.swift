//
//  InAppPresentationManager.swift
//  Mindbox
//
//  Created by Максим Казаков on 06.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit
import MindboxLogger

struct InAppMessageUIModel {
    struct InAppRedirect {
        let redirectUrl: String
        let payload: String
    }
    let inAppId: String
    let image: UIImage
    let redirect: InAppRedirect
}

protocol InAppPresentationManagerProtocol: AnyObject {
    func present(
        inAppFormData: InAppFormData,
        onPresented: @escaping () -> Void,
        onTapAction: @escaping InAppMessageTapAction,
        onPresentationCompleted: @escaping () -> Void,
        onError: @escaping (InAppPresentationError) -> Void
    )
}

enum InAppPresentationError {
    case failedToLoadImages
    case failedToLoadWindow
    case failed(String)
}

typealias InAppMessageTapAction = (_ tapLink: URL?, _ payload: String) -> Void

final class InAppPresentationManager: InAppPresentationManagerProtocol {

    private let actionHandler: InAppActionHandlerProtocol
    private let displayUseCase: PresentationDisplayUseCase

    init(actionHandler: InAppActionHandlerProtocol,
         displayUseCase: PresentationDisplayUseCase) {
        self.actionHandler = actionHandler
        self.displayUseCase = displayUseCase

        addObserverToDismissInApp()
    }
    
    private func addObserverToDismissInApp() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("shouldDiscardInapps"),
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.displayUseCase.dismissInAppUIModel(onClose: { })
        }
    }

    func present(
        inAppFormData: InAppFormData,
        onPresented: @escaping () -> Void,
        onTapAction: @escaping InAppMessageTapAction,
        onPresentationCompleted: @escaping () -> Void,
        onError: @escaping (InAppPresentationError) -> Void
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                onError(.failed("[InAppPresentationManager] Self guard not passed."))
                return
            }

            self.displayUseCase.presentInAppUIModel(model: inAppFormData,
                                                    onPresented: {
                self.displayUseCase.onPresented(id: inAppFormData.inAppId, onPresented)
            }, onTapAction: { [weak self] action in
                guard let self = self,
                      let action = action else {
                    return
                }

                self.actionHandler.handleAction(action, for: inAppFormData.inAppId, onTap: onTapAction, close: {
                    self.displayUseCase.dismissInAppUIModel(onClose: onPresentationCompleted)
                })
            }, onClose: {
                self.displayUseCase.dismissInAppUIModel(onClose: onPresentationCompleted)
            })
        }
    }
}
