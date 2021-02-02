//
//  MockPersistenceStorage.swift
//  MindBoxTests
//
//  Created by Mikhail Barilov on 29.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
@testable import MindBox

class MockPersistenceStorage: PersistenceStorage {
    
    init() {

    }
    
    var deviceUUID: String?

    var installationId: String?

    var isInstalled: Bool = false

    var apnsToken: String?

    var apnsTokenSaveDate: Date?

    func reset() {
        deviceUUID = nil
        installationId = nil
        isInstalled = false
        apnsToken = nil
        apnsTokenSaveDate = nil
    }

}
