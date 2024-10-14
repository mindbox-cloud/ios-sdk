//
//  EventRepositoryTestCase.swift
//  MindboxTests
//
//  Created by Maksim Kazachkov on 03.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

@testable import Mindbox
import XCTest

// swiftlint:disable force_try

class EventRepositoryTestCase: XCTestCase {
    var coreController: CoreController!
    var controllerQueue: DispatchQueue!
    var persistenceStorage: PersistenceStorage!
    
    override func setUp() {
        super.setUp()
        persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        coreController = DI.injectOrFail(CoreController.self)
        controllerQueue = coreController.controllerQueue
        persistenceStorage.reset()
        let databaseRepository = DI.injectOrFail(MBDatabaseRepository.self)
        try! databaseRepository.erase()
    }
    
    override func tearDown() {
        
        coreController = nil
        controllerQueue = nil
        super.tearDown()
    }
    
    func testSendEvent() {
        let configuration = try! MBConfiguration(plistName: "TestEventConfig")
        coreController.initialization(configuration: configuration)
        waitForInitializationFinished()
        let repository = DI.injectOrFail(EventRepository.self)
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
        let repository = DI.injectOrFail(EventRepository.self)
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
