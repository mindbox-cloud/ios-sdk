//
//  VersioningTest.swift
//  MindboxTests
//
//  Created by Maksim Kazachkov on 09.04.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

@testable import Mindbox
import XCTest

class VersioningTestCase: XCTestCase {
    private var queues: [DispatchQueue] = []

    var container: DependencyContainer!

    override func setUp() {
        super.setUp()
        container = try! TestDependencyProvider()
        container.persistenceStorage.reset()
        try! container.databaseRepository.erase()
        Mindbox.shared.assembly(with: container)
        TimerManager.shared.invalidate()
        queues = []
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    func testInfoUpdateVersioningByAPNSToken() {
        let inspectVersionsExpectation = expectation(description: "InspectVersion")
        initConfiguration()
        container.guaranteedDeliveryManager.canScheduleOperations = false
        let infoUpdateLimit = 50
        makeMockAsyncCall(limit: infoUpdateLimit) { _ in
            let deviceToken = APNSTokenGenerator().generate()
            Mindbox.shared.apnsTokenUpdate(deviceToken: deviceToken)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            do {
                let events = try self.container.databaseRepository.query(fetchLimit: infoUpdateLimit)
                events.forEach({
                    XCTAssertTrue($0.type == .infoUpdated)
                })
                events
                    .sorted { $0.dateTimeOffset > $1.dateTimeOffset }
                    .compactMap { BodyDecoder<MobileApplicationInfoUpdated>(decodable: $0.body)?.body }
                    .enumerated()
                    .makeIterator()
                    .forEach { offset, element in
                        XCTAssertTrue(offset + 1 == element.version, "Element version is \(element.version). Current element is \(offset + 1). Are they equal? \(offset + 1 == element.version)")
                    }
                inspectVersionsExpectation.fulfill()
            } catch {
                XCTFail(error.localizedDescription)
            }
        }

        waitForExpectations(timeout: 60, handler: nil)
    }

    func testInfoUpdateVersioningByRequestAuthorization() {
        let inspectVersionsExpectation = expectation(description: "InspectVersion")
        initConfiguration()
        container.guaranteedDeliveryManager.canScheduleOperations = false
        let infoUpdateLimit = 50
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.makeMockAsyncCall(limit: infoUpdateLimit) { index in
                Mindbox.shared.notificationsRequestAuthorization(granted: index % 2 == 0)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            do {
                let events = try self.container.databaseRepository.query(fetchLimit: infoUpdateLimit)
                events.forEach({
                    XCTAssertTrue($0.type == .infoUpdated)
                })
                events
                    .sorted { $0.dateTimeOffset > $1.dateTimeOffset }
                    .compactMap { BodyDecoder<MobileApplicationInfoUpdated>(decodable: $0.body)?.body }
                    .enumerated()
                    .makeIterator()
                    .forEach { offset, element in
                        XCTAssertTrue(offset + 1 == element.version, "Element version is \(element.version). Current element is \(offset + 1). Are they equal? \(offset + 1 == element.version)")
                    }
                inspectVersionsExpectation.fulfill()
            } catch {
                XCTFail(error.localizedDescription)
            }
        }

        waitForExpectations(timeout: 60, handler: nil)
    }

    private func initConfiguration() {
        let configuration = try! MBConfiguration(
            endpoint: "mpush-test-iOS-test",
            domain: "api.mindbox.ru",
            previousInstallationId: "",
            previousDeviceUUID: UUID().uuidString,
            subscribeCustomerIfCreated: true
        )
        Mindbox.shared.initialization(configuration: configuration)
    }

    private func makeMockAsyncCall(limit: Int, mockSDKCall: @escaping ((Int) -> Void)) {
        (1 ... limit)
            .map { index in
                DispatchWorkItem {
                    mockSDKCall(index)
                }
            }
            .enumerated()
            .makeIterator()
            .forEach { index, workItem in
                let queue = DispatchQueue(label: "com.Mindbox.testInfoUpdateVersioning-\(index)", attributes: .concurrent)
                queues.append(queue)
                queue.async(execute: workItem)
            }
    }
}
