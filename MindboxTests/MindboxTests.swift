//
//  MindboxTests.swift
//  MindboxTests
//
//  Created by Mikhail Barilov on 12.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import XCTest
@testable import Mindbox

class MindboxTests: XCTestCase {
    var mindBoxDidInstalledFlag: Bool = false
    var apnsTokenDidUpdatedFlag: Bool = false

    var container: DependencyContainer!
    var coreController: CoreController!

    override func setUp() {
        container = try! TestDependencyProvider()
        container.persistenceStorage.reset()
        try! container.databaseRepository.erase()
        Mindbox.shared.assembly(with: container)
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        queues = []
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
        Mindbox.shared.getDeviceUUID { value in
            deviceUUID = value
        }
        XCTAssertNotNil(deviceUUID)
        //        //        //        //        //        //        //        //        //        //        //        //
        let configuration2 = try! MBConfiguration(plistName: "TestConfig2")
        coreController.initialization(configuration: configuration2)
        coreController.apnsTokenDidUpdate(token: UUID().uuidString)
        XCTAssertTrue(container.persistenceStorage.isInstalled)
        XCTAssertNotNil(container.persistenceStorage.apnsToken)
        var deviceUUID2: String?
        Mindbox.shared.getDeviceUUID { value in
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
    
    func testGetDeviceUUID() {
        var deviceUuid: String?
        Mindbox.shared.getDeviceUUID { value in
            deviceUuid = value
        }
        let configuration = try! MBConfiguration(
            endpoint: "mpush-test-iOS-test",
            domain: "api.mindbox.ru",
            installationId: "",
            deviceUUID: "",
            subscribeCustomerIfCreated: true
        )
        Mindbox.shared.initialization(configuration: configuration)

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
            installationId: "",
            deviceUUID: "",
            subscribeCustomerIfCreated: true
        )
        Mindbox.shared.initialization(configuration: configuration)

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
    
    private var queues: [DispatchQueue] = []
    
    func testInfoUpdateVersioning() {
        let createEventsExpectation = self.expectation(description: "CreateInfoUpdate")
        let inspectVersionsExpectation = self.expectation(description: "InspectVersion")
        let configuration = try! MBConfiguration(
            endpoint: "mpush-test-iOS-test",
            domain: "api.mindbox.ru",
            installationId: "",
            deviceUUID: UUID().uuidString,
            subscribeCustomerIfCreated: true
        )
        Mindbox.shared.initialization(configuration: configuration)
        container.guaranteedDeliveryManager.canScheduleOperations = false
        queues = []
        let infoUpdateLimit = 50
        (1...infoUpdateLimit).forEach { index in
            let queue = DispatchQueue(label: "com.Mindbox.testInfoUpdateVersioning-\(index)", attributes: .concurrent)
            queues.append(queue)
            queue.async {
                Mindbox.shared.apnsTokenUpdate(deviceToken: self.mockToken())
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let count = self.container.databaseRepository.count
            XCTAssertTrue(count == infoUpdateLimit)
            createEventsExpectation.fulfill()
            do {
                let events = try self.container.databaseRepository.query(fetchLimit: infoUpdateLimit)
                events.forEach({
                    XCTAssertTrue($0.type == .infoUpdated)
                })
                let decodedBodies = events
                    .sorted { $0.dateTimeOffset > $1.dateTimeOffset }
                    .compactMap { BodyDecoder<MobileApplicationInfoUpdated>(decodable: $0.body)?.body  }
                
                XCTAssertTrue(decodedBodies.count == infoUpdateLimit)
                decodedBodies
                    .enumerated()
                    .makeIterator()
                    .forEach { (offset, element) in
                        XCTAssertTrue(offset + 1 == element.version)
                    }
                inspectVersionsExpectation.fulfill()
            } catch {
                XCTFail(error.localizedDescription)
            }
        }
        
        waitForExpectations(timeout: 60, handler: nil)
    }
    
    private func mockToken() -> Data {
        (1...8)
            .map { _ in randomString(length: 8) + " " }
            .reduce("", +)
            .data(using: .utf8)!
    }
    
    private func randomString(length: Int = 10) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map{ _ in letters.randomElement()! })
    }
    
}