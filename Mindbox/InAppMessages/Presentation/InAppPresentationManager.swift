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

    /// Closes the overlay on screen, if any, through its normal completion path — the host hears
    /// `inAppMessageDismissed` and the lock is released the same way a user's close releases it.
    /// Main thread only.
    func dismissActiveInApp()
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

    private let displayUseCase: PresentationDisplayUseCaseProtocol

    /// The active show's completion, kept so an outside dismissal finishes that show the same way the
    /// view's own close button would. Main-confined, like the shows themselves.
    ///
    /// The token is what lets a show release only its own completion: releasing without one would let a
    /// finishing show clear the slot a newer show has already taken.
    private var activePresentation: (token: UUID, complete: () -> Void)?

    init(displayUseCase: PresentationDisplayUseCaseProtocol) {
        self.displayUseCase = displayUseCase

        addObserverToDismissInApp()
    }

    func dismissActiveInApp() {
        displayUseCase.dismissInAppUIModel(onClose: activePresentation?.complete ?? {})
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
        let token = UUID()
        // A finished show releases its completion, and with it the form data — images included — that
        // the completion holds.
        let releaseActivePresentation: () -> Void = { [weak self] in
            guard self?.activePresentation?.token == token else { return }

            self?.activePresentation = nil
        }
        let safeOnError: (InAppPresentationError) -> Void = { error in
            DispatchQueue.main.async {
                releaseActivePresentation()
                callbackGuard.finishWithError {
                    onError(error)
                }
            }
        }
        let safeOnPresentationCompleted: () -> Void = {
            DispatchQueue.main.async {
                releaseActivePresentation()
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

            self.activePresentation = (token, safeOnPresentationCompleted)
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
