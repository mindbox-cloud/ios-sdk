//
//  MindboxTests.swift
//  MindboxTests
//
//  Created by Mikhail Barilov on 12.01.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

// swiftlint:disable force_try

fileprivate enum ConstantsForTests {
    static let token = "740f4707 bebcf74f 9b7c25d4 8e335894 5f6aa01d a5ddb387 462c7eaf 61bb78ad"
    static let pushTokenKeepaliveNotification = Constants.Notification.pushTokenKeepalive
}

class MindboxTests: XCTestCase {
    var mindBoxDidInstalledFlag: Bool = false
    var apnsTokenDidUpdatedFlag: Bool = false

    var coreController: CoreController!
    var controllerQueue = DispatchQueue(label: "test-core-controller-queue")
    var persistenceStorage: PersistenceStorage!
    var databaseRepository: DatabaseRepositoryProtocol!

    override func setUp() {
        super.setUp()
        persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        persistenceStorage.reset()
        databaseRepository = DI.injectOrFail(DatabaseRepositoryProtocol.self)
        try! databaseRepository.erase()
        Mindbox.shared.assembly()
        Mindbox.shared.coreController?.controllerQueue = self.controllerQueue
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        super.tearDown()
        persistenceStorage = nil
        databaseRepository = nil
        coreController = nil
    }

    func testInitialization() {
        coreController = DI.injectOrFail(CoreController.self)
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
        let databaseRepository = DI.injectOrFail(DatabaseRepositoryProtocol.self)
        try! databaseRepository.erase()
        coreController = DI.injectOrFail(CoreController.self)

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

        let tokenData = Data(ConstantsForTests.token.utf8)
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
        let tokenData = Data(ConstantsForTests.token.utf8)
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
}

// MARK: - PushTokenKeepalive

extension MindboxTests {
    
    func testSendKeepaliveAfterInstallation() {
        XCTAssertFalse(persistenceStorage.isInstalled)
        XCTAssertNil(persistenceStorage.lastInfoUpdateDate)
        XCTAssertNil(databaseRepository.infoUpdateVersion)
        
        initializeCoreController()
        XCTAssertNotNil(persistenceStorage.lastInfoUpdateDate, "It should have been updated with the `ApplicationInstalled` event")
        
        delay(for: .seconds(3))
        
        let pushToken = "0.00:00:02"
        sendPushTokenKeepaliveNotification(with: pushToken)
        
        controllerQueue.sync { }
        
        XCTAssertNotNil(persistenceStorage.lastInfoUpdateDate)
        XCTAssertNotNil(databaseRepository.infoUpdateVersion)
        XCTAssertEqual(databaseRepository.infoUpdateVersion, 1, "InfoUpdate must be incremented")
        
        let result = try? databaseRepository.query(fetchLimit: 5)
        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(result?.last?.type, .keepAlive, "Event type must be `keepAlive`")
    }
    
    func testSendKeepaliveAfterInstallationAndInfoUpdate_whenExpired() {
        XCTAssertFalse(persistenceStorage.isInstalled)
        XCTAssertNil(persistenceStorage.lastInfoUpdateDate)
        XCTAssertNil(databaseRepository.infoUpdateVersion)
        
        initializeCoreController()
        XCTAssertNotNil(persistenceStorage.lastInfoUpdateDate, "It should have been updated with the `ApplicationInstalled` event")
        
        coreController.apnsTokenDidUpdate(token: UUID().uuidString)
        controllerQueue.sync { }
        
        delay(for: .seconds(3))
        
        let pushToken = "0.00:00:02"
        sendPushTokenKeepaliveNotification(with: pushToken)

        controllerQueue.sync { }
        
        XCTAssertNotNil(self.persistenceStorage.lastInfoUpdateDate)
        XCTAssertNotNil(databaseRepository.infoUpdateVersion)
        XCTAssertEqual(databaseRepository.infoUpdateVersion, 2, "InfoUpdate must be incremented twice")
        
        let result = try? databaseRepository.query(fetchLimit: 5)
        XCTAssertEqual(result?.count, 2)
        
        XCTAssertEqual(result?.first?.type, .infoUpdated, "First event type must be `infoUpdated`")
        XCTAssertEqual(result?.last?.type, .keepAlive, "Last event type must be `keepAlive`")
    }
    
    func testMustUpdateLastInfoUpdateOnlyAfterInstallation() {
        coreController = DI.injectOrFail(CoreController.self)
        XCTAssertFalse(persistenceStorage.isInstalled)
        XCTAssertNil(persistenceStorage.lastInfoUpdateDate)
        XCTAssertNil(databaseRepository.infoUpdateVersion)
        
        coreController.apnsTokenDidUpdate(token: UUID().uuidString)
        controllerQueue.sync { }
        
        XCTAssertFalse(persistenceStorage.isInstalled)
        XCTAssertNil(persistenceStorage.lastInfoUpdateDate, "It must be nil because we won't send an `InfoUpdate` before installation because the DB will be erased during installation")
        XCTAssertNotNil(databaseRepository.infoUpdateVersion)
        XCTAssertEqual(databaseRepository.infoUpdateVersion, 1)
        XCTAssertEqual(try databaseRepository.countEvents(), 1)
        
        initializeCoreController()
        XCTAssertNotNil(persistenceStorage.lastInfoUpdateDate, "It should have been updated with the `ApplicationInstalled` event")
        
        delay(for: .seconds(3))
        
        let pushToken = "0.00:00:02"
        sendPushTokenKeepaliveNotification(with: pushToken)

        controllerQueue.sync { }
        
        XCTAssertNotNil(persistenceStorage.lastInfoUpdateDate)
        XCTAssertNotNil(databaseRepository.infoUpdateVersion)
        XCTAssertEqual(databaseRepository.infoUpdateVersion, 1, "InfoUpdate must be incremented once")
        
        let result = try? databaseRepository.query(fetchLimit: 5)
        XCTAssertEqual(result?.count, 1)
        
        XCTAssertEqual(result?.last?.type, .keepAlive, "Last event type must be `keepAlive`")
    }
    
    func test_PushTokenKeepalive_withLastInfoUpdateDateIsNil_shouldSendOperation() {
        XCTAssertFalse(persistenceStorage.isInstalled)
        XCTAssertNil(persistenceStorage.lastInfoUpdateDate)
        XCTAssertNil(databaseRepository.infoUpdateVersion)
        
        initializeCoreController()
        persistenceStorage.lastInfoUpdateDate = nil
        
        delay(for: .seconds(3))
        
        let pushToken = "0.00:10:02"
        sendPushTokenKeepaliveNotification(with: pushToken)
        
        controllerQueue.sync { }
        
        XCTAssertNotNil(persistenceStorage.lastInfoUpdateDate)
        XCTAssertNotNil(databaseRepository.infoUpdateVersion)
        XCTAssertEqual(databaseRepository.infoUpdateVersion, 1, "InfoUpdate must be incremented")
        
        let result = try? databaseRepository.query(fetchLimit: 5)
        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(result?.last?.type, .keepAlive, "Event type must be `keepAlive`")
    }
    
    func test_PushTokenKeepalive_doesNotSendOperationWhenNotExpired() {
        generalNegativeTestPushTokenKeepalive(with: "0.00:00:10")
    }
    
    func test_PushTokenKeepalive_doesNotSendOperationWhenTokenFromConfigIsNotSet() {
        generalNegativeTestPushTokenKeepalive(with: nil)
    }
    
    func test_PushTokenKeepalive_doesNotSendOperationWhenTokenFromConfigIsInvalid() {
        generalNegativeTestPushTokenKeepalive(with: "foo")
    }
    
    func test_PushTokenKeepalive_doesNotSendOperationWhenTokenFromConfigIsLessThenZero() {
        generalNegativeTestPushTokenKeepalive(with: "-0.0:0:02")
    }
    
    func test_PushTokenKeepalive_doesNotSendOperationWhenTokenFromConfigIsZero() {
        generalNegativeTestPushTokenKeepalive(with: "0.0:0:00")
    }
}

private extension MindboxTests {
    func waitForInitializationFinished() {
        let expectation = self.expectation(description: "controller initialization")
        controllerQueue.async { expectation.fulfill() }
        self.wait(for: [expectation], timeout: 10)
    }
    
    func delay(for timeInterval: DispatchTimeInterval) {
        let expectation = XCTestExpectation(description: "delay")
        DispatchQueue.main.asyncAfter(deadline: .now() + timeInterval) {
            expectation.fulfill()
        }

        let timeout = timeInterval.timeIntervalValue + 1.0
        wait(for: [expectation], timeout: timeout)
    }
    
    func sendPushTokenKeepaliveNotification(with pushToken: String?) {
        NotificationCenter.default.post(
            name: .receivedPushTokenKeepaliveFromTheMobileConfig,
            object: nil,
            userInfo: [ConstantsForTests.pushTokenKeepaliveNotification: pushToken as Any]
        )
    }
    
    func initializeCoreController() {
        coreController = DI.injectOrFail(CoreController.self)
        let configuration1 = try! MBConfiguration(plistName: "TestConfig1")
        coreController.initialization(configuration: configuration1)
        waitForInitializationFinished()
        DI.injectOrFail(GuaranteedDeliveryManager.self).canScheduleOperations = false
    }
    
    func generalNegativeTestPushTokenKeepalive(with pushTokenKeepalive: String?, file: StaticString = #file, line: UInt = #line) {
        XCTAssertFalse(persistenceStorage.isInstalled, file: file, line: line)
        XCTAssertNil(persistenceStorage.lastInfoUpdateDate, file: file, line: line)
        XCTAssertNil(databaseRepository.infoUpdateVersion, file: file, line: line)
        
        initializeCoreController()
        XCTAssertNotNil(persistenceStorage.lastInfoUpdateDate, "It should have been updated with the `ApplicationInstalled` event", file: file, line: line)
        
        coreController.apnsTokenDidUpdate(token: UUID().uuidString)
        controllerQueue.sync { }
        
        delay(for: .seconds(2))
        
        let configResponse = Settings.SlidingExpiration(config: "0.00:30:00", pushTokenKeepalive: pushTokenKeepalive)
        sendPushTokenKeepaliveNotification(with: configResponse.pushTokenKeepalive)
        
        controllerQueue.sync { }
        
        XCTAssertNotNil(self.persistenceStorage.lastInfoUpdateDate, file: file, line: line)
        XCTAssertNotNil(databaseRepository.infoUpdateVersion, file: file, line: line)
        XCTAssertEqual(databaseRepository.infoUpdateVersion, 1, "InfoUpdate must be incremented only by apnsTokenDidUpdate", file: file, line: line)
        
        let result = try? databaseRepository.query(fetchLimit: 5)
        XCTAssertEqual(result?.count, 1, file: file, line: line)
        
        XCTAssertEqual(result?.first?.type, .infoUpdated, "First event type must be `infoUpdated`", file: file, line: line)
    }
}

extension DispatchTimeInterval {
    
    var timeIntervalValue: TimeInterval {
        switch self {
        case .seconds(let s):         return TimeInterval(s)
        case .milliseconds(let ms):   return TimeInterval(ms) / 1_000.0
        case .microseconds(let us):   return TimeInterval(us) / 1_000_000.0
        case .nanoseconds(let ns):    return TimeInterval(ns) / 1_000_000_000.0
        case .never:                  return .infinity
        @unknown default:             return 0
        }
    }
}
