//
//  MindBoxTests.swift
//  MindBoxTests
//
//  Created by Mikhail Barilov on 12.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import XCTest
@testable import MindBox

class MindBoxTests: XCTestCase {

    var mindBoxDidInstalledFlag: Bool = false
    var apnsTokenDidUpdatedFlag: Bool = false

    var databaseRepository: MBDatabaseRepository!
    var gdManager: GuaranteedDeliveryManager!
    var persistenceStorage: PersistenceStorage!
    
    override func setUp() {
        diManager.dropContainer()
        diManager.registerServices()
        diManager.container.registerInContainer { _ -> DataBaseLoader in
            return try! MockDataBaseLoader()
        }
        diManager.container.registerInContainer { _ -> PersistenceStorage in
            MockPersistenceStorage()
        }
        diManager.container.register { (r) -> NetworkFetcher in
            MockNetworkFetcher()
        }
        diManager.container.registerInContainer { _ -> UNAuthorizationStatusProviding in
            MockUNAuthorizationStatusProvider(status: .authorized)
        }
        databaseRepository = diManager.container.resolve()
        persistenceStorage = diManager.container.resolve()
        persistenceStorage.reset()
        try! databaseRepository.erase()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testOnInitCase1() {
        var coreController = CoreController()
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let configuration1 = try! MBConfiguration(plistName: "TestConfig1")
        coreController.initialization(configuration: configuration1)
        XCTAssertTrue(persistenceStorage.isInstalled)
        let deviceUUID =  try! MindBox.shared.deviceUUID()
    	//        //        //        //        //        //		//        //        //        //        //        //
        let configuration2 = try! MBConfiguration(plistName: "TestConfig2")
        coreController.initialization(configuration: configuration2)
        coreController.apnsTokenDidUpdate(token: UUID().uuidString)
        XCTAssertTrue(persistenceStorage.isInstalled)
        XCTAssertNotNil(persistenceStorage.apnsToken)
        let deviceUUID2 = try! MindBox.shared.deviceUUID()
        XCTAssert(deviceUUID == deviceUUID2)

        let persistensStorage: PersistenceStorage = diManager.container.resolveOrDie()

        persistensStorage.reset()
        try! databaseRepository.erase()
        coreController = CoreController()

        //        //        //        //        //        //        //        //        //        //        //        //

        let configuration3 = try! MBConfiguration(plistName: "TestConfig3")
        coreController.initialization(configuration: configuration3)
        coreController.apnsTokenDidUpdate(token: UUID().uuidString)
        XCTAssertTrue(persistenceStorage.isInstalled)
        XCTAssertNotNil(persistenceStorage.apnsToken)
    }

}
