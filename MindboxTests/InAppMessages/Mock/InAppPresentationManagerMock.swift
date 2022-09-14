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
    var receivedInAppUIModel: InAppMessageUIModel?
    func present(inAppUIModel: InAppMessageUIModel) {
        receivedInAppUIModel = inAppUIModel
    }
}
