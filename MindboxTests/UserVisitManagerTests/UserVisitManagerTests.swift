//
//  UserVisitManagerTests.swift
//  Mindbox
//
//  Created by Egor Kitseliuk on 22.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

final class UserVisitManagerTests: XCTestCase {
    
    private var persistenceStorageMock: PersistenceStorage!
    private var userVisitManager: UserVisitManagerProtocol!
    private var sessionManagerMock: MockSessionManager!
    private var container: TestDependencyProvider!
    
    override func setUp() {
        super.setUp()
        container = try! TestDependencyProvider()
        persistenceStorageMock = MockPersistenceStorage()
        userVisitManager = UserVisitManager(persistenceStorage: persistenceStorageMock)
        persistenceStorageMock.deviceUUID = "00000000-0000-0000-0000-000000000000"
    }
    
    func test_save_first_user_visit_for_first_initialization() throws {
        userVisitManager.saveUserVisit()
        
        XCTAssertEqual(persistenceStorageMock.userVisitCount, 1)
    }
    
    func test_save_user_visit_for_difference_session() throws {
        persistenceStorageMock.userVisitCount = 1
        
        userVisitManager.saveUserVisit()
        XCTAssertEqual(persistenceStorageMock.userVisitCount, 2)
        
        userVisitManager = UserVisitManager(persistenceStorage: persistenceStorageMock)
        userVisitManager.saveUserVisit()
        
        XCTAssertEqual(persistenceStorageMock.userVisitCount, 3)
    }

    func test_save_not_first_user_visit_for_first_initialization() throws {
        persistenceStorageMock.userVisitCount = 10
        persistenceStorageMock.installationDate = Date()
        SessionTemporaryStorage.shared.isInstalledFromPersistenceStorageBeforeInitSDK = persistenceStorageMock.isInstalled
        
        userVisitManager.saveUserVisit()
        
        XCTAssertEqual(persistenceStorageMock.userVisitCount, 11)
    }
    
    func test_save_first_user_visit_for_not_first_initialization() throws {
        persistenceStorageMock.installationDate = Date()
        SessionTemporaryStorage.shared.isInstalledFromPersistenceStorageBeforeInitSDK = persistenceStorageMock.isInstalled
        
        userVisitManager.saveUserVisit()
        
        XCTAssertEqual(persistenceStorageMock.userVisitCount, 2)
    }
    
    func test_save_not_first_user_visit_for_not_first_initialization() throws {
        persistenceStorageMock.userVisitCount = 10
        
        userVisitManager.saveUserVisit()
        
        XCTAssertEqual(persistenceStorageMock.userVisitCount, 11)
    }
    
    func test_save_user_visit_twice() throws {
        persistenceStorageMock.userVisitCount = 10
        
        userVisitManager.saveUserVisit()
        userVisitManager.saveUserVisit()
        
        XCTAssertEqual(persistenceStorageMock.userVisitCount, 11)
    }
}
