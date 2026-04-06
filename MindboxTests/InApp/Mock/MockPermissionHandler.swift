//
//  MockPermissionHandler.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 16.03.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
@testable import Mindbox

final class MockPermissionHandler: PermissionHandler {

    let permissionType: PermissionType
    let requiredInfoPlistKeys: [String]

    var stubbedResult: PermissionRequestResult = .granted(dialogShown: false)
    private(set) var requestCallCount = 0

    init(permissionType: PermissionType, requiredInfoPlistKeys: [String] = []) {
        self.permissionType = permissionType
        self.requiredInfoPlistKeys = requiredInfoPlistKeys
    }

    func request(completion: @escaping (PermissionRequestResult) -> Void) {
        requestCallCount += 1
        completion(stubbedResult)
    }
}
