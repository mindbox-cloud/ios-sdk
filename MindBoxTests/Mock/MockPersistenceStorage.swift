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
    
    var deprecatedEventsRemoveDate: Date?
    
    var configuration: MBConfiguration?

    var backgroundExecutions: [BackgroudExecution] = []
    
    var isNotificationsEnabled: Bool?
    
    var installationDate: Date?

    func reset() {
        deviceUUID = nil
        installationId = nil
        isInstalled = false
        apnsToken = nil
        apnsTokenSaveDate = nil
        deprecatedEventsRemoveDate = nil
        configuration = nil
        backgroundExecutions = []
        isNotificationsEnabled = false
        installationDate = nil
    }
    
    
    func setBackgroundExecution(_ value: BackgroudExecution) {
        backgroundExecutions.append(value)
    }
    
    func resetBackgroundExecutions() {
        backgroundExecutions = []
    }
    
    func storeToFileBackgroundExecution() {
        
    }
    
    

}
