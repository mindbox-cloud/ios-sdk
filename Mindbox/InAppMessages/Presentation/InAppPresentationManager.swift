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
    case webviewLoadFailed(String)
    case webviewPresentationFailed(String)
    case failed(String)
}

extension InAppPresentationError {
    var failureReason: InAppShowFailureReason {
        switch self {
        case .webviewLoadFailed:
            return .webviewLoadFailed
        case .webviewPresentationFailed:
            return .webviewPresentationFailed
        default:
            return .presentationFailed
        }
    }

    var failureDetails: String? {
        switch self {
        case .failedToLoadImages:
            return "[InAppPresentationError] Failed to load images."
        case .failedToLoadWindow:
            return "[InAppPresentationError] Failed to load window."
        case .webviewLoadFailed(let details), .webviewPresentationFailed(let details), .failed(let details):
            return details
        }
    }
}

typealias InAppMessageTapAction = (_ tapLink: URL?, _ payload: String) -> Void

final class InAppPresentationManager: InAppPresentationManagerProtocol {

    private let displayUseCase: PresentationDisplayUseCase

    init(displayUseCase: PresentationDisplayUseCase) {
        self.displayUseCase = displayUseCase

        addObserverToDismissInApp()
    }

    private func addObserverToDismissInApp() {
        NotificationCenter.default.addObserver(
            forName: .shouldDiscardInapps,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.displayUseCase.dismissInAppUIModel(onClose: { })
            }
        }
    }

    func present(
        inAppFormData: InAppFormData,
        onPresented: @escaping () -> Void,
        onTapAction: @escaping InAppMessageTapAction,
        onPresentationCompleted: @escaping () -> Void,
        onError: @escaping (InAppPresentationError) -> Void
    ) {
        let callbackGuard = PresentationCallbackGuard()
        let safeOnError: (InAppPresentationError) -> Void = { error in
            DispatchQueue.main.async {
                callbackGuard.finishWithError {
                    onError(error)
                }
            }
        }
        let safeOnPresentationCompleted: () -> Void = {
            DispatchQueue.main.async {
                callbackGuard.finishSuccessfully {
                    onPresentationCompleted()
                }
            }
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                safeOnError(.failed("[InAppPresentationManager] Self guard not passed."))
                return
            }

            self.displayUseCase.presentInAppUIModel(model: inAppFormData,
                                                    onPresented: {
                self.displayUseCase.onPresented(id: inAppFormData.inAppId, onPresented)
            }, onTapAction: onTapAction,
            onClose: {
                self.displayUseCase.dismissInAppUIModel(onClose: safeOnPresentationCompleted)
            },
            onError: safeOnError)
        }
    }
}

private final class PresentationCallbackGuard {
    private var isTerminalEventHandled = false

    func finishWithError(_ action: () -> Void) {
        guard beginTerminalEventIfNeeded() else {
            return
        }
        action()
    }

    func finishSuccessfully(_ action: () -> Void) {
        guard beginTerminalEventIfNeeded() else {
            return
        }
        action()
    }

    private func beginTerminalEventIfNeeded() -> Bool {
        guard !isTerminalEventHandled else {
            return false
        }
        isTerminalEventHandled = true
        return true
    }
}
