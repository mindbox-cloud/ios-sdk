//
//  InAppCoreManagerMock.swift
//  MindboxTests
//
//  Created by Максим Казаков on 13.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation
@testable import Mindbox

class InAppCoreManagerMock: InAppCoreManagerProtocol {
    weak var delegate: InAppMessagesDelegate?

    var discardEventsCalled = false
    var sendEventCalled: [InAppMessageTriggerEvent] = []

    func start() {
    }

    func sendEvent(_ event: InAppMessageTriggerEvent) {
        sendEventCalled.append(event)
    }

    func discardEvents() {
        discardEventsCalled = true
    }
}
