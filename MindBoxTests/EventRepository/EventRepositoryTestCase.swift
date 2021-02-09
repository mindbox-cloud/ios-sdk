//
//  EventRepositoryTestCase.swift
//  MindBoxTests
//
//  Created by Maksim Kazachkov on 03.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import XCTest
@testable import MindBox

class EventRepositoryTestCase: XCTestCase {
    
    var coreController: CoreController!
    
    var isMockNetworkFetcher = true
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        DIManager.shared.dropContainer()
        DIManager.shared.registerServices()
        DIManager.shared.container.registerInContainer { _ -> PersistenceStorage in
            MockPersistenceStorage()
        }
        if isMockNetworkFetcher {
            DIManager.shared.container.register { _ -> NetworkFetcher in
                MockNetworkFetcher()
            }
        }
        DIManager.shared.container.register { _ -> UNAuthorizationStatusProviding in
            MockUNAuthorizationStatusProvider(status: .authorized)
        }
        coreController = CoreController()
    }
    
    func testSendEvent() {
        let configuration = try! MBConfiguration(plistName: "TestEventConfig")
        coreController.initialization(configuration: configuration)
        let repository: EventRepository = DIManager.shared.container.resolveOrDie()
        let event = Event(
            transactionId: UUID().uuidString,
            enqueueTimeStamp: Date().timeIntervalSince1970,
            type: .installed,
            body: ""
        )
        let expectation = self.expectation(description: "send event")
        repository.send(event: event) { (result) in
            switch result {
            case .success:
                expectation.fulfill()
            case .failure:
                XCTFail()
            }
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
    
}


