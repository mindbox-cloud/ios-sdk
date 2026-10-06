//
//  InAppPresentationManagerMock.swift
//  MindboxTests
//
//  Created by Максим Казаков on 14.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation
@testable import Mindbox

class InAppPresentationManagerMock: InAppPresentationManagerProtocol {
    var receivedInAppUIModel: InAppFormData?
    var presentCallsCount = 0
    var discardActiveCallsCount = 0
    var receivedOnPresent: (() -> Void)?
    var receivedOnPresentationCompleted: ((Bool) -> Void)?
    var receivedOnError: ((InAppPresentationError) -> Void)?
    private(set) var presentedOnMainThread: Bool?

    /// Like the real manager, a present closes the show already up, but at once rather than a turn later.
    var hasActivePresentation = false
    private var activeShow = 0

    var isPresenting: Bool { hasActivePresentation }

    func present(inAppFormData: InAppFormData,
                 onPresented: @escaping () -> Void,
                 onTapAction: @escaping InAppMessageTapAction,
                 onPresentationCompleted: @escaping (Bool) -> Void,
                 onError: @escaping (InAppPresentationError) -> Void) {
        presentCallsCount += 1
        presentedOnMainThread = Thread.isMainThread
        closeActive(wasDiscarded: false)

        activeShow += 1
        let show = activeShow
        let release = { [weak self] in
            guard let self, self.activeShow == show else { return }
            self.hasActivePresentation = false
        }
        receivedInAppUIModel = inAppFormData
        receivedOnPresent = onPresented
        receivedOnPresentationCompleted = { wasDiscarded in
            release()
            onPresentationCompleted(wasDiscarded)
        }
        receivedOnError = { error in
            release()
            onError(error)
        }
        hasActivePresentation = true
    }

    func closeActiveInApp() {
        closeActive(wasDiscarded: false)
    }

    func discardActiveInApp() {
        discardActiveCallsCount += 1
        closeActive(wasDiscarded: true)
    }

    private func closeActive(wasDiscarded: Bool) {
        guard hasActivePresentation else { return }

        hasActivePresentation = false
        receivedOnPresentationCompleted?(wasDiscarded)
    }
}

final class PresentationDisplaySpy: PresentationDisplayUseCaseProtocol {
    private(set) var presentCount = 0
    private(set) var dismissCount = 0
    private(set) var onScreen: String?
    private(set) var reportedOnScreen: [String] = []

    private(set) var receivedOnClose: (() -> Void)?
    private(set) var receivedOnPresented: (() -> Void)?
    private(set) var receivedOnError: ((InAppPresentationError) -> Void)?

    var closesWhilePresenting = false

    func presentInAppUIModel(model: InAppFormData,
                             onPresented: @escaping () -> Void,
                             onTapAction: @escaping InAppMessageTapAction,
                             onClose: @escaping () -> Void,
                             onError: @escaping (InAppPresentationError) -> Void) {
        presentCount += 1
        receivedOnClose = onClose
        receivedOnPresented = onPresented
        receivedOnError = onError
        if closesWhilePresenting {
            onError(.webviewPresentationFailed("closed while presenting"))
            onClose()
        }
        onScreen = model.inAppId
    }

    func dismissInAppUIModel() {
        dismissCount += 1
        onScreen = nil
        receivedOnClose = nil
        receivedOnPresented = nil
        receivedOnError = nil
    }

    func onPresented(id: String, _ completion: @escaping () -> Void) {
        reportedOnScreen.append(id)
        completion()
    }
}
