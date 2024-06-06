//
//  EventRepositoryTestCase.swift
//  MindboxTests
//
//  Created by Maksim Kazachkov on 03.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

@testable import Mindbox
import XCTest

class EventRepositoryTestCase: XCTestCase {
    var coreController: CoreController!
    var container: DependencyContainer!
    var controllerQueue: DispatchQueue!
    
    override func setUp() {
        super.setUp()
        container = try! TestDependencyProvider()
        controllerQueue = DispatchQueue(label: "test-core-controller-queue")
        coreController = CoreController(
            persistenceStorage: container.persistenceStorage,
//            utilitiesFetcher: container.utilitiesFetcher,
            notificationStatusProvider: container.authorizationStatusProvider,
            databaseRepository: container.databaseRepository,
            guaranteedDeliveryManager: container.guaranteedDeliveryManager,
            trackVisitManager: container.instanceFactory.makeTrackVisitManager(),
            sessionManager: container.sessionManager,
            inAppMessagesManager: InAppCoreManagerMock(),
            uuidDebugService: MockUUIDDebugService(),
            controllerQueue: controllerQueue,
            userVisitManager: container.userVisitManager
        )
        container.persistenceStorage.reset()
        try! container.databaseRepository.erase()
    }
    
    override func tearDown() {
        
        coreController = nil
        container = nil
        controllerQueue = nil
        super.tearDown()
    }
    
    func testSendEvent() {
        let configuration = try! MBConfiguration(plistName: "TestEventConfig")
        coreController.initialization(configuration: configuration)
        waitForInitializationFinished()
        let repository: EventRepository = container.instanceFactory.makeEventRepository()
        let event = Event(
            type: .installed,
            body: ""
        )
        let expectation = self.expectation(description: "send event")
        repository.send(event: event) { result in
            switch result {
                case .success:
                    expectation.fulfill()
                case .failure:
                    XCTFail()
            }
        }
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testSendDecodableEvent() {
        let configuration = try! MBConfiguration(plistName: "TestEventConfig")
        coreController.initialization(configuration: configuration)
        waitForInitializationFinished()
        let repository: EventRepository = container.instanceFactory.makeEventRepository()
        let event = Event(type: .syncEvent, body: "")
        let expectation = self.expectation(description: "send event")
        repository.send(type: SuccessCase.self, event: event) { result in
            switch result {
                case let .success(data):
                    if data.status == "Success" {
                        expectation.fulfill()
                    } else {
                        XCTFail()
                    }
                case .failure:
                    XCTFail()
            }
        }
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    private struct SuccessCase: Decodable {
        let status: String
    }
    
    private func waitForInitializationFinished() {
        let expectation = self.expectation(description: "controller initialization")
        controllerQueue.async { expectation.fulfill() }
        self.wait(for: [expectation], timeout: 2)
    }
}
