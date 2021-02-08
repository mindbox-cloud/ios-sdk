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
        configurationStorage.save(configuration: configuration)
        configurationStorage.set(uuid: "0593B5CC-1479-4E45-A7D3-F0E8F9B40898")
        if guaranteedDeliveryManager == nil {
            guaranteedDeliveryManager = GuaranteedDeliveryManager()
        }
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    func testGuaranteedDeliveryManager() {
        let expectation = self.expectation(description: "GuaranteedDelivery")
        let event = eventGenerator.generateEvent()
        do {
            try databaseRepository.create(event: event)
        } catch {
            XCTFail(error.localizedDescription)
        }
        if !guaranteedDeliveryManager.isDelivering {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 10)
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
