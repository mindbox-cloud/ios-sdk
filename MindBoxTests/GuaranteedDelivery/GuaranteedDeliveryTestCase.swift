//
//  GuaranteedDeliveryTestCase.swift
//  MindBoxTests
//
//  Created by Maksim Kazachkov on 08.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import XCTest
import CoreData
@testable import MindBox

class GuaranteedDeliveryTestCase: XCTestCase {
    
    var databaseRepository: MockDatabaseRepository!
    var guaranteedDeliveryManager: GuaranteedDeliveryManager!
    
    let eventGenerator = EventGenerator()
    
    var isDelivering: Bool {
        guaranteedDeliveryManager.state.isDelivering
    }
    
    override func setUp() {
        DIManager.shared.dropContainer()
        DIManager.shared.registerServices()
        DIManager.shared.container.register { _ -> NetworkFetcher in
            MockNetworkFetcher()
        }
        DIManager.shared.container.registerInContainer { _ -> MBDatabaseRepository in
            try! MockDatabaseRepository()
        }
        if databaseRepository == nil {
            let dependency: MBDatabaseRepository = DIManager.shared.container.resolveOrDie()
            databaseRepository = dependency as? MockDatabaseRepository
        }
        let configuration = try! MBConfiguration(plistName: "TestEventConfig")
        let configurationStorage: ConfigurationStorage = DIManager.shared.container.resolveOrDie()
        configurationStorage.setConfiguration(configuration)
        configurationStorage.set(uuid: "0593B5CC-1479-4E45-A7D3-F0E8F9B40898")
        if guaranteedDeliveryManager == nil {
            guaranteedDeliveryManager = GuaranteedDeliveryManager()
        }
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    func testIsDelivering() {
        let event = eventGenerator.generateEvent()
        do {
            try databaseRepository.create(event: event)
        } catch {
            XCTFail(error.localizedDescription)
        }
        let exists = NSPredicate(format: "isDelivering == false")
        expectation(for: exists, evaluatedWith: self, handler: nil)
        waitForExpectations(timeout: 60, handler: nil)
    }
    
    func testDeliverMultipleEvents() {
        let events = eventGenerator.generateEvents(count: 10)
        events.forEach {
            do {
                try databaseRepository.create(event: $0)
            } catch {
                XCTFail(error.localizedDescription)
            }
        }
        let deliveringExpectation = NSPredicate(format: "%K == %@", argumentArray: [#keyPath(state), GuaranteedDeliveryManager.State.idle.rawValue])
        expectation(for: deliveringExpectation, evaluatedWith: self, handler: nil)
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    var state: NSString {
        NSString(string: guaranteedDeliveryManager.state.rawValue)
    }
    
    func testScheduleByTimer() {
        let retryDeadline: TimeInterval = 3
        guaranteedDeliveryManager = GuaranteedDeliveryManager(retryDeadline: retryDeadline)
        guaranteedDeliveryManager.canScheduleOperations = false
        let count = 2
        let events = eventGenerator.generateEvents(count: count)
        do {
            try events.forEach {
                try databaseRepository.create(event: $0)
            }
        } catch {
            XCTFail(error.localizedDescription)
        }
        do {
            try events.forEach {
                try databaseRepository.update(event: $0)
            }
            guaranteedDeliveryManager.canScheduleOperations = true
        } catch {
            XCTFail(error.localizedDescription)
        }
        let expectDeadline = 2 * retryDeadline
        let retryExpectation = NSPredicate(format: "%K == %@", argumentArray: [#keyPath(state), GuaranteedDeliveryManager.State.idle.rawValue])
        expectation(for: retryExpectation, evaluatedWith: self, handler: nil)
        waitForExpectations(timeout: expectDeadline)
    }
    
    private func generateAndSaveToDatabaseEvents() {
        let event = eventGenerator.generateEvent()
        do {
            try databaseRepository.create(event: event)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
}
