//
//  MockUUIDDebugService.swift
//  MindboxTests
//
//  Created by Aleksandr Svetilov on 12.08.2022.
//

import Foundation
@testable import Mindbox

final class MockUUIDDebugService: UUIDDebugService {

    var invokedStart = false
    var invokedStartCount = 0
    var invokedStartParameters: (uuid: String, Void)?
    var invokedStartParametersList = [(uuid: String, Void)]()

    func start(with uuid: String) {
        invokedStart = true
        invokedStartCount += 1
        invokedStartParameters = (uuid, ())
        invokedStartParametersList.append((uuid, ()))
    }
}
