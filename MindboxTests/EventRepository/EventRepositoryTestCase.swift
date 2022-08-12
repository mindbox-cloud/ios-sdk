//
//  EventRepositoryTestCase.swift
//  MindboxTests
//
//  Created by Maksim Kazachkov on 03.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

@testable import Mindbox
import XCTest

class EventRepositoryTestCase: XCTestCase {
    var coreController: CoreController!

    var container: DependencyContainer!

    override func setUp() {
        container = try! TestDependencyProvider()
        coreController = CoreController(
            persistenceStorage: container.persistenceStorage,
            utilitiesFetcher: container.utilitiesFetcher,
            notificationStatusProvider: container.authorizationStatusProvider,
            databaseRepository: container.databaseRepository,
            guaranteedDeliveryManager: container.guaranteedDeliveryManager,
            trackVisitManager: container.instanceFactory.makeTrackVisitManager(),
            sessionManager: container.sessionManager,
            uuidDebugService: MockUUIDDebugService()
        )
        container.persistenceStorage.reset()
        try! container.databaseRepository.erase()
    }

    func testSendEvent() {
        let configuration = try! MBConfiguration(plistName: "TestEventConfig")
        coreController.initialization(configuration: configuration)
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
        waitForExpectations(timeout: 10, handler: nil)
    }

    func testSendDecodableEvent() {
        let configuration = try! MBConfiguration(plistName: "TestEventConfig")
        coreController.initialization(configuration: configuration)
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
        waitForExpectations(timeout: 10, handler: nil)
    }

    private struct SuccessCase: Decodable {
        let status: String
    }
}
