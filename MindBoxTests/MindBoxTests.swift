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

    var container: DependencyContainer!
    var coreController: CoreController!
    
    override func setUp() {
        container = try! TestDependencyProvider()
        container.persistenceStorage.reset()
        try! container.databaseRepository.erase()
        MindBox.shared.assembly(with: container)
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testOnInitCase1() {
        coreController = CoreController(
            persistenceStorage: container.persistenceStorage,
            utilitiesFetcher: container.utilitiesFetcher,
            notificationStatusProvider: container.authorizationStatusProvider,
            databaseRepository: container.databaseRepository,
            guaranteedDeliveryManager: container.guaranteedDeliveryManager
        )
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let configuration1 = try! MBConfiguration(plistName: "TestConfig1")
        coreController.initialization(configuration: configuration1)
        XCTAssertTrue(container.persistenceStorage.isInstalled)
        var deviceUUID: String?
        MindBox.shared.getDeviceUUID { (value) in
            deviceUUID = value
        }
        XCTAssertNotNil(deviceUUID)
    	//        //        //        //        //        //		//        //        //        //        //        //
        let configuration2 = try! MBConfiguration(plistName: "TestConfig2")
        coreController.initialization(configuration: configuration2)
        coreController.apnsTokenDidUpdate(token: UUID().uuidString)
        XCTAssertTrue(container.persistenceStorage.isInstalled)
        XCTAssertNotNil(container.persistenceStorage.apnsToken)
        var deviceUUID2: String?
        MindBox.shared.getDeviceUUID { (value) in
            deviceUUID2 = value
        }
        XCTAssertNotNil(deviceUUID2)
        XCTAssert(deviceUUID == deviceUUID2)

        container.persistenceStorage.reset()
        try! container.databaseRepository.erase()
        coreController = CoreController(
            persistenceStorage: container.persistenceStorage,
            utilitiesFetcher: container.utilitiesFetcher,
            notificationStatusProvider: container.authorizationStatusProvider,
            databaseRepository: container.databaseRepository,
            guaranteedDeliveryManager: container.guaranteedDeliveryManager
        )

        //        //        //        //        //        //        //        //        //        //        //        //

        let configuration3 = try! MBConfiguration(plistName: "TestConfig3")
        coreController.initialization(configuration: configuration3)
        coreController.apnsTokenDidUpdate(token: UUID().uuidString)
        XCTAssertTrue(container.persistenceStorage.isInstalled)
        XCTAssertNotNil(container.persistenceStorage.apnsToken)
    }

}
