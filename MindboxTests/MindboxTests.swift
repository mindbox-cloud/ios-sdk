//
//  MindboxTests.swift
//  MindboxTests
//
//  Created by Mikhail Barilov on 12.01.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

class MindboxTests: XCTestCase {
    var mindBoxDidInstalledFlag: Bool = false
    var apnsTokenDidUpdatedFlag: Bool = false

    var container: DependencyContainer!
    var coreController: CoreController!
    var controllerQueue = DispatchQueue(label: "test-core-controller-queue")
    var persistenceStorage: PersistenceStorage!

    override func setUp() {
        container = try! TestDependencyProvider()
        persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        persistenceStorage.reset()
        try! container.databaseRepository.erase()
        Mindbox.shared.assembly(with: container)
        Mindbox.shared.coreController?.controllerQueue = self.controllerQueue
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testInitialization() {
        coreController = CoreController(
            persistenceStorage: persistenceStorage,
            utilitiesFetcher: container.utilitiesFetcher,
            databaseRepository: container.databaseRepository,
            guaranteedDeliveryManager: DI.injectOrFail(GuaranteedDeliveryManager.self),
            trackVisitManager: DI.injectOrFail(TrackVisitManager.self),
            sessionManager: DI.injectOrFail(SessionManager.self),
            inAppMessagesManager: InAppCoreManagerMock(),
            uuidDebugService: MockUUIDDebugService(),
            controllerQueue: controllerQueue, 
            userVisitManager: DI.injectOrFail(UserVisitManagerProtocol.self)
        )
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let configuration1 = try! MBConfiguration(plistName: "TestConfig1")
        coreController.initialization(configuration: configuration1)

        waitForInitializationFinished()

        XCTAssertTrue(persistenceStorage.isInstalled)
        var deviceUUID: String?
        Mindbox.shared.getDeviceUUID { value in
            deviceUUID = value
        }
        XCTAssertNotNil(deviceUUID)
        //        //        //        //        //        //        //        //        //        //        //        //
        let configuration2 = try! MBConfiguration(plistName: "TestConfig2")
        coreController.initialization(configuration: configuration2)
        coreController.apnsTokenDidUpdate(token: UUID().uuidString)

        waitForInitializationFinished()

        XCTAssertTrue(persistenceStorage.isInstalled)
        XCTAssertNotNil(persistenceStorage.apnsToken)
        var deviceUUID2: String?
        Mindbox.shared.getDeviceUUID { value in
            deviceUUID2 = value
        }
        XCTAssertNotNil(deviceUUID2)
        XCTAssert(deviceUUID == deviceUUID2)

        persistenceStorage.reset()
        try! container.databaseRepository.erase()
        coreController = CoreController(
            persistenceStorage: persistenceStorage,
            utilitiesFetcher: container.utilitiesFetcher,
            databaseRepository: container.databaseRepository,
            guaranteedDeliveryManager: DI.injectOrFail(GuaranteedDeliveryManager.self),
            trackVisitManager: DI.injectOrFail(TrackVisitManager.self),
            sessionManager: DI.injectOrFail(SessionManager.self),
            inAppMessagesManager: InAppCoreManagerMock(),
            uuidDebugService: MockUUIDDebugService(),
            controllerQueue: controllerQueue,
            userVisitManager: DI.injectOrFail(UserVisitManagerProtocol.self)
        )

        //        //        //        //        //        //        //        //        //        //        //        //

        let configuration3 = try! MBConfiguration(plistName: "TestConfig3")
        coreController.initialization(configuration: configuration3)
        coreController.apnsTokenDidUpdate(token: UUID().uuidString)

        waitForInitializationFinished()

        XCTAssertTrue(persistenceStorage.isInstalled)
        XCTAssertNotNil(persistenceStorage.apnsToken)
    }

    func testGetDeviceUUID() {
        var deviceUuid: String?
        Mindbox.shared.getDeviceUUID { value in
            deviceUuid = value
        }
        let configuration = try! MBConfiguration(
            endpoint: "mpush-test-iOS-test",
            domain: "api.mindbox.ru",
            previousInstallationId: "",
            previousDeviceUUID: "",
            subscribeCustomerIfCreated: true
        )
        Mindbox.shared.initialization(configuration: configuration)
        waitForInitializationFinished()

        var newDeviceUuid: String?
        Mindbox.shared.getDeviceUUID { value in
            newDeviceUuid = value
        }

        XCTAssertNotNil(deviceUuid)
        XCTAssertNotNil(newDeviceUuid)
        XCTAssertEqual(newDeviceUuid, deviceUuid)
    }

    func testGetDeviceUUIDDouble() {
        var firstDeviceUuidCount = 0
        Mindbox.shared.getDeviceUUID { _ in
            firstDeviceUuidCount += 1
        }
        let configuration = try! MBConfiguration(
            endpoint: "mpush-test-iOS-test",
            domain: "api.mindbox.ru",
            previousInstallationId: "",
            previousDeviceUUID: "",
            subscribeCustomerIfCreated: true
        )
        Mindbox.shared.initialization(configuration: configuration)
        waitForInitializationFinished()

        var secondDeviceUuidCount = 0
        Mindbox.shared.getDeviceUUID { _ in
            secondDeviceUuidCount += 1
        }

        Mindbox.shared.getDeviceUUID { _ in }
        Mindbox.shared.getDeviceUUID { _ in }
        Mindbox.shared.getDeviceUUID { _ in }

        XCTAssertEqual(firstDeviceUuidCount, 1)
        XCTAssertEqual(secondDeviceUuidCount, 1)
    }

    func testGetApnsToken() {
        var firstApnsToken: String?
        Mindbox.shared.getAPNSToken { token in
            firstApnsToken = token
        }

        let tokenData = "740f4707 bebcf74f 9b7c25d4 8e335894 5f6aa01d a5ddb387 462c7eaf 61bb78ad".data(using: .utf8)!
        let tokenString = tokenData.map { String(format: "%02.2hhx", $0) }.joined()

        Mindbox.shared.apnsTokenUpdate(deviceToken: tokenData)
        waitForInitializationFinished()

        var secondApnsToken: String?
        Mindbox.shared.getAPNSToken { token in
            secondApnsToken = token
        }
        XCTAssertNotNil(firstApnsToken)
        XCTAssertNotNil(secondApnsToken)
        XCTAssertEqual(firstApnsToken, secondApnsToken)
        XCTAssertEqual(firstApnsToken, tokenString)
        XCTAssertEqual(secondApnsToken, tokenString)
    }

    func testGetApnsTokenDouble() {
        var firstCountApnsToken = 0
        Mindbox.shared.getAPNSToken { _ in
            firstCountApnsToken += 1
        }
        let tokenData = "740f4707 bebcf74f 9b7c25d4 8e335894 5f6aa01d a5ddb387 462c7eaf 61bb78ad".data(using: .utf8)!
        Mindbox.shared.apnsTokenUpdate(deviceToken: tokenData)
        waitForInitializationFinished()

        var secondCountApnsToken = 0
        Mindbox.shared.getAPNSToken { _ in
            secondCountApnsToken += 1
        }

        Mindbox.shared.getAPNSToken { _ in }
        Mindbox.shared.getAPNSToken { _ in }
        Mindbox.shared.getAPNSToken { _ in }

        XCTAssertEqual(firstCountApnsToken, 1)
        XCTAssertEqual(secondCountApnsToken, 1)
    }

    func testOperationNameValidity() {
        XCTAssertTrue("TEST.-".operationNameIsValid)
        XCTAssertFalse("тест".operationNameIsValid)
        XCTAssertFalse("TESт".operationNameIsValid)
    }

    private func waitForInitializationFinished() {
        let expectation = self.expectation(description: "controller initialization")
        controllerQueue.async { expectation.fulfill() }
        self.wait(for: [expectation], timeout: 10)
    }
}
