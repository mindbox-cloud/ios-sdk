//
//  VersioningTest.swift
//  MindboxTests
//
//  Created by Maksim Kazachkov on 09.04.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

@testable import Mindbox
import XCTest

// swiftlint:disable force_try

//class VersioningTestCase: XCTestCase {
//    private var queues: [DispatchQueue] = []
//
//    var persistenceStorage: PersistenceStorage!
//    var databaseRepository: MBDatabaseRepository!
//    var guaranteedDeliveryManager: GuaranteedDeliveryManager!
//
//    override func setUp() {
//        super.setUp()
//        persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
//        persistenceStorage.reset()
//        databaseRepository = DI.injectOrFail(MBDatabaseRepository.self)
//        try! databaseRepository.erase()
//        guaranteedDeliveryManager = DI.injectOrFail(GuaranteedDeliveryManager.self)
//        Mindbox.shared.assembly()
//        let timer = DI.injectOrFail(TimerManager.self)
//        timer.invalidate()
//        queues = []
//        // Put setup code here. This method is called before the invocation of each test method in the class.
//    }
//
//    override func tearDown() {
//        persistenceStorage = nil
//        databaseRepository = nil
//        guaranteedDeliveryManager = nil
//        queues.removeAll()
//
//        super.tearDown()
//    }
//
//    func testInfoUpdateVersioningByAPNSToken() {
//        let inspectVersionsExpectation = expectation(description: "InspectVersion")
//        initConfiguration()
////        container.guaranteedDeliveryManager.canScheduleOperations = false
//        guaranteedDeliveryManager.canScheduleOperations = true
//        let infoUpdateLimit = 2
//        makeMockAsyncCall(limit: infoUpdateLimit) { _ in
//            let deviceToken = APNSTokenGenerator().generate()
//            print("Updating APNS token: \(deviceToken)")
//            Mindbox.shared.apnsTokenUpdate(deviceToken: deviceToken)
//        }
//
//        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
//            do {
////                let events = try self.container.databaseRepository.query(fetchLimit: infoUpdateLimit)
//                let events = try self.databaseRepository.query(fetchLimit: infoUpdateLimit)
//                XCTAssertNotEqual(events.count, 0)
//                events.forEach({
//                    XCTAssertTrue($0.type == .infoUpdated)
//                })
//
//                print("\n\n\n")
//                print(events.count)
//                print("\n\n\n")
//                events
//                    .sorted { $0.dateTimeOffset > $1.dateTimeOffset }
//                    .compactMap { BodyDecoder<MobileApplicationInfoUpdated>(decodable: $0.body)?.body }
//                    .enumerated()
//                    .makeIterator()
//                    .forEach { offset, element in
//                        XCTAssertTrue(offset + 1 == element.version, "Element version is \(element.version). Current element is \(offset + 1). Are they equal? \(offset + 1 == element.version)")
//                    }
//                inspectVersionsExpectation.fulfill()
//            } catch {
//                XCTFail(error.localizedDescription)
//            }
//        }
//
//        waitForExpectations(timeout: 60, handler: nil)
//    }
//
//    func testInfoUpdateVersioningByRequestAuthorization() {
//        let inspectVersionsExpectation = expectation(description: "InspectVersion")
//        initConfiguration()
////        container.guaranteedDeliveryManager.canScheduleOperations = false
//        guaranteedDeliveryManager.canScheduleOperations = false
//        let infoUpdateLimit = 50
//
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//            self.makeMockAsyncCall(limit: infoUpdateLimit) { index in
//                Mindbox.shared.notificationsRequestAuthorization(granted: index % 2 == 0)
//            }
//        }
//
//        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
//            do {
////                let events = try self.container.databaseRepository.query(fetchLimit: infoUpdateLimit)
//                let events = try self.databaseRepository.query(fetchLimit: infoUpdateLimit)
//                events.forEach({
//                    XCTAssertTrue($0.type == .infoUpdated)
//                })
//                events
//                    .sorted { $0.dateTimeOffset > $1.dateTimeOffset }
//                    .compactMap { BodyDecoder<MobileApplicationInfoUpdated>(decodable: $0.body)?.body }
//                    .enumerated()
//                    .makeIterator()
//                    .forEach { offset, element in
//                        XCTAssertTrue(offset + 1 == element.version, "Element version is \(element.version). Current element is \(offset + 1). Are they equal? \(offset + 1 == element.version)")
//                    }
//                inspectVersionsExpectation.fulfill()
//            } catch {
//                XCTFail(error.localizedDescription)
//            }
//        }
//
//        waitForExpectations(timeout: 60, handler: nil)
//    }
//}
//
//extension VersioningTestCase {
//    private func initConfiguration() {
//        let configuration = try! MBConfiguration(
//            endpoint: "mpush-test-iOS-test",
//            domain: "api.mindbox.ru",
//            previousInstallationId: "",
//            previousDeviceUUID: UUID().uuidString,
//            subscribeCustomerIfCreated: true
//        )
//        Mindbox.shared.initialization(configuration: configuration)
//    }
//
//    private func makeMockAsyncCall(limit: Int, mockSDKCall: @escaping ((Int) -> Void)) {
//
//        (1 ... limit)
//            .map { index in
//                DispatchWorkItem {
//                    mockSDKCall(index)
//                }
//            }
//            .enumerated()
//            .makeIterator()
//            .forEach { index, workItem in
//                let queue = DispatchQueue(label: "com.Mindbox.testInfoUpdateVersioning-\(index)", attributes: .concurrent)
//                queues.append(queue)
//                queue.async(execute: workItem)
//            }
//    }
//}


//private func makeMockAsyncCall(limit: Int, mockSDKCall: @escaping ((Int) -> Void)) {
//
//    let dispatchGroup = DispatchGroup()
//
//    (1...limit).forEach { index in
//        dispatchGroup.enter()
//        let queue = DispatchQueue(label: "com.Mindbox.testInfoUpdateVersioning-\(index)", attributes: .concurrent)
//        queues.append(queue)
//        queue.async {
//            mockSDKCall(index)
//            dispatchGroup.leave()
//        }
//    }
//
//    dispatchGroup.wait()
//}
