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

    func start() {
    }

    func sendEvent(_ event: InAppMessageTriggerEvent) {
    }
}
