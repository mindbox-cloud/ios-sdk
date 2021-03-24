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
    
    var deviceUUID: String? {
        didSet {
            configuration?.deviceUUID = deviceUUID
        }
    }

    var installationId: String?

    var isInstalled: Bool {
        installationDate != nil
    }

    var apnsToken: String? {
        didSet {
            apnsTokenSaveDate = Date()
        }
    }

    var apnsTokenSaveDate: Date?
    
    var deprecatedEventsRemoveDate: Date?
    
    var configuration: MBConfiguration?

    var backgroundExecutions: [BackgroudExecution] = []
    
    var isNotificationsEnabled: Bool?
    
    var installationDate: Date?

    func reset() {
        installationDate = nil
        deviceUUID = nil
        installationId = nil
        apnsToken = nil
        apnsTokenSaveDate = nil
        deprecatedEventsRemoveDate = nil
        configuration = nil
        isNotificationsEnabled = nil
        resetBackgroundExecutions()
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
