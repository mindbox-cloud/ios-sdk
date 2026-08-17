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
    var dismissActiveCallsCount = 0
    var receivedOnPresent: (() -> Void)?
    var receivedOnPresentationCompleted: (() -> Void)?
    var receivedOnError: ((InAppPresentationError) -> Void)?

    /// `true` — a show is on screen: `dismissActiveInApp` completes it, the way the real manager
    /// routes an outside dismissal through the show's own completion.
    var hasActivePresentation = false

    func present(inAppFormData: InAppFormData,
                 onPresented: @escaping () -> Void,
                 onTapAction: @escaping InAppMessageTapAction,
                 onPresentationCompleted: @escaping () -> Void,
                 onError: @escaping (InAppPresentationError) -> Void) {
        presentCallsCount += 1
        receivedInAppUIModel = inAppFormData
        receivedOnPresent = onPresented
        receivedOnPresentationCompleted = onPresentationCompleted
        receivedOnError = onError
        hasActivePresentation = true
    }

    func dismissActiveInApp() {
        dismissActiveCallsCount += 1

        guard hasActivePresentation else { return }

        hasActivePresentation = false
        receivedOnPresentationCompleted?()
    }
}
