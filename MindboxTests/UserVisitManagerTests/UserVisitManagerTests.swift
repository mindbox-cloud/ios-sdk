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
    private var userVisitManager: UserVisitManager!
    private var sessionManagerMock: MockSessionManager!
    private var container: TestDependencyProvider!
    
    override func setUp() {
        super.setUp()
        container = try! TestDependencyProvider()
        persistenceStorageMock = MockPersistenceStorage()
        sessionManagerMock = MockSessionManager()
        userVisitManager = UserVisitManager(persistenceStorage: persistenceStorageMock, sessionManager: sessionManagerMock)
        SessionTemporaryStorage.shared.isInitialiazionCalled = true
        SessionTemporaryStorage.shared.isFirstInitialiazion = false
        sessionManagerMock._isActiveNow = true
    }

    func test_save_first_user_visit_no_active() throws {
        sessionManagerMock._isActiveNow = false
        
        userVisitManager.saveUserVisit()
        
        XCTAssertEqual(persistenceStorageMock.userVisitCount, 0)
    }
    
    func test_save_not_first_user_visit_no_active() throws {
        persistenceStorageMock.userVisitCount = 42
        sessionManagerMock._isActiveNow = false
        
        userVisitManager.saveUserVisit()
        
        XCTAssertEqual(persistenceStorageMock.userVisitCount, 42)
    }
    
    func test_save_first_user_visit_no_init_and_no_active() throws {
        SessionTemporaryStorage.shared.isInitialiazionCalled = false
        sessionManagerMock._isActiveNow = false
        
        userVisitManager.saveUserVisit()
        
        XCTAssertEqual(persistenceStorageMock.userVisitCount, 0)
    }
    
    func test_save_first_user_visit_no_init() throws {
        SessionTemporaryStorage.shared.isInitialiazionCalled = false
        
        userVisitManager.saveUserVisit()
        
        XCTAssertEqual(persistenceStorageMock.userVisitCount, 0)
    }
    
    func test_save_not_first_user_visit_no_init() throws {
        persistenceStorageMock.userVisitCount = 42
        SessionTemporaryStorage.shared.isInitialiazionCalled = false
        
        userVisitManager.saveUserVisit()
        
        XCTAssertEqual(persistenceStorageMock.userVisitCount, 42)
    }

    func test_save_first_user_visit_for_first_initialization() throws {
        SessionTemporaryStorage.shared.isFirstInitialiazion = true
        
        userVisitManager.saveUserVisit()
        
        XCTAssertEqual(persistenceStorageMock.userVisitCount, 1)
    }
    
    func test_save_user_visit_for_difference_session() throws {
        persistenceStorageMock.userVisitCount = 1
        
        userVisitManager.saveUserVisit()
        XCTAssertEqual(persistenceStorageMock.userVisitCount, 2)
        
        userVisitManager = UserVisitManager(persistenceStorage: persistenceStorageMock, sessionManager: sessionManagerMock)
        userVisitManager.saveUserVisit()
        
        XCTAssertEqual(persistenceStorageMock.userVisitCount, 3)
    }

    func test_save_not_first_user_visit_for_first_initialization() throws {
        persistenceStorageMock.userVisitCount = 10
        SessionTemporaryStorage.shared.isFirstInitialiazion = true
        
        userVisitManager.saveUserVisit()
        
        XCTAssertEqual(persistenceStorageMock.userVisitCount, 11)
    }
    
    func test_save_first_user_visit_for_not_first_initialization() throws {
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
