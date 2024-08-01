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
    
    var shownInappsDictionary: [String : Date]?
    
    func migrateShownInAppsIds() {
        
    }
    
    var handledlogRequestIds: [String]?
    
    var imageLoadingMaxTimeInSeconds: Double?
    
    private var _userVisitCount: Int? = 0
    
    var userVisitCount: Int? {
        get { return _userVisitCount }
        set { _userVisitCount = newValue }
    }
    
    private var _versionCodeForMigration: Int? = 0
    
    var versionCodeForMigration: Int? {
        get { return _versionCodeForMigration }
        set { _versionCodeForMigration = newValue }
    }

    var configDownloadDate: Date? {
        didSet { 
            onDidChange?()
        }
    }
    
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
    
    func softReset() {
        configuration = nil
        
        configDownloadDate = nil
        
        shownInAppsIds = nil // Deprecated
        shownInappsDictionary = nil
        
        userVisitCount = 0
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
    
    var needUpdateInfoOnce: Bool? {
        didSet {
            onDidChange?()
        }
    }

}
