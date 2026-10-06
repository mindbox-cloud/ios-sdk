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
    /// Closes the overlay already up, as a user's close would, then shows this one. Main thread only.
    func present(
        inAppFormData: InAppFormData,
        onPresented: @escaping () -> Void,
        onTapAction: @escaping InAppMessageTapAction,
        onPresentationCompleted: @escaping (_ wasDiscarded: Bool) -> Void,
        onError: @escaping (InAppPresentationError) -> Void
    )

    /// The session is over: closes the overlay through the show's completion, so a waiting request is answered,
    /// but not as the user's close: no cooldown, no dismissed callback to the host, in sync with Android. Main thread only.
    func discardActiveInApp()

    var isPresenting: Bool { get }
}

enum InAppPresentationError: Error {
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

    private final class ActivePresentation {
        let token: UUID
        let complete: (_ wasDiscarded: Bool) -> Void
        var isClosing = false

        init(token: UUID, complete: @escaping (_ wasDiscarded: Bool) -> Void) {
            self.token = token
            self.complete = complete
        }
    }

    private let displayUseCase: PresentationDisplayUseCaseProtocol

    /// Main-confined, like the shows.
    private var activePresentation: ActivePresentation?

    var isPresenting: Bool { activePresentation != nil }

    init(displayUseCase: PresentationDisplayUseCaseProtocol) {
        self.displayUseCase = displayUseCase

        addObserverToDismissInApp()
    }

    func discardActiveInApp() {
        guard let active = activePresentation else { return }

        finish(active.token, wasDiscarded: true)
    }

    private func finish(_ token: UUID, wasDiscarded: Bool) {
        guard let active = activePresentation, active.token == token, !active.isClosing else { return }

        active.isClosing = true
        displayUseCase.dismissInAppUIModel()
        active.complete(wasDiscarded)
    }

    private func isOnScreen(_ token: UUID) -> Bool {
        guard let active = activePresentation else { return false }

        return active.token == token && !active.isClosing
    }

    private func addObserverToDismissInApp() {
        NotificationCenter.default.addObserver(
            forName: .shouldDiscardInapps,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.discardActiveInApp()
            }
        }
    }

    func present(
        inAppFormData: InAppFormData,
        onPresented: @escaping () -> Void,
        onTapAction: @escaping InAppMessageTapAction,
        onPresentationCompleted: @escaping (_ wasDiscarded: Bool) -> Void,
        onError: @escaping (InAppPresentationError) -> Void
    ) {
        guard Thread.isMainThread else {
            Logger.common(message: "[InAppPresentationManager] present called off the main thread, moving it there",
                          level: .error, category: .inAppMessages)
            DispatchQueue.main.async {
                self.present(inAppFormData: inAppFormData,
                             onPresented: onPresented,
                             onTapAction: onTapAction,
                             onPresentationCompleted: onPresentationCompleted,
                             onError: onError)
            }
            return
        }

        if let active = activePresentation {
            finish(active.token, wasDiscarded: false)
        }

        let callbackGuard = PresentationCallbackGuard()
        let token = UUID()
        // Releasing the completion also releases the form data — images included — that it holds.
        let releaseActivePresentation: () -> Void = { [weak self] in
            guard self?.activePresentation?.token == token else { return }

            self?.activePresentation = nil
        }
        let safeOnError: (InAppPresentationError) -> Void = { [weak self] error in
            DispatchQueue.main.async {
                self?.finish(token, wasDiscarded: false)
                releaseActivePresentation()
                callbackGuard.finishWithError {
                    onError(error)
                }
            }
        }
        let safeOnPresentationCompleted: (Bool) -> Void = { wasDiscarded in
            DispatchQueue.main.async {
                releaseActivePresentation()
                callbackGuard.finishSuccessfully {
                    onPresentationCompleted(wasDiscarded)
                }
            }
        }

        let presentation = ActivePresentation(token: token, complete: safeOnPresentationCompleted)
        activePresentation = presentation
        displayUseCase.presentInAppUIModel(model: inAppFormData,
                                           onPresented: { [weak self] in
            guard let self, self.isOnScreen(token) else { return }
            self.displayUseCase.onPresented(id: inAppFormData.inAppId, onPresented)
        }, onTapAction: onTapAction,
        onClose: { [weak self] in
            self?.finish(token, wasDiscarded: false)
        },
        onError: safeOnError)

        if presentation.isClosing {
            displayUseCase.dismissInAppUIModel()
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
