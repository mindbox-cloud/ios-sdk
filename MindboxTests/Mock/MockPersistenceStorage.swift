//
//  MockPersistenceStorage.swift
//  MindboxTests
//
//  Created by Mikhail Barilov on 29.01.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
@testable import Mindbox

class MockPersistenceStorage: PersistenceStorage {
    
    var onDidChange: (() -> Void)?
    
    init() {

    }
    
    var deviceUUID: String? {
        didSet {
            configuration?.previousDeviceUUID = deviceUUID
            onDidChange?()
        }
    }

    var installationId: String? {
        didSet {
            onDidChange?()
        }
    }

    var isInstalled: Bool {
        installationDate != nil
    }

    var apnsToken: String? {
        didSet {
            apnsTokenSaveDate = Date()
        }
    }

    var apnsTokenSaveDate: Date? {
        didSet {
            onDidChange?()
        }
    }
    
    var deprecatedEventsRemoveDate: Date? {
        didSet {
            onDidChange?()
        }
    }
    
    var configuration: MBConfiguration? {
        didSet {
            onDidChange?()
        }
    }

    var backgroundExecutions: [BackgroudExecution] = [] {
        didSet {
            onDidChange?()
        }
    }
    
    var isNotificationsEnabled: Bool? {
        didSet {
            onDidChange?()
        }
    }
    
    var installationDate: Date? {
        didSet {
            onDidChange?()
        }
    }

    var shownInAppsIds: [String]?
    
    var handledlogRequestIds: [String]?

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
