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

class VersioningTestCase: XCTestCase {
    private var queues: [DispatchQueue] = []

    var persistenceStorage: PersistenceStorage!
    var databaseRepository: MBDatabaseRepository!
    var guaranteedDeliveryManager: GuaranteedDeliveryManager!

    override func setUp() {
        super.setUp()

        persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        persistenceStorage.reset()

        databaseRepository = DI.injectOrFail(MBDatabaseRepository.self)
        try! databaseRepository.erase()

        guaranteedDeliveryManager = DI.injectOrFail(GuaranteedDeliveryManager.self)
        Mindbox.shared.assembly()
        let timer = DI.injectOrFail(TimerManager.self)
        timer.invalidate()

        queues = []
    }

    override func tearDown() {
        persistenceStorage = nil
        databaseRepository = nil
        guaranteedDeliveryManager = nil
        queues.removeAll()
        super.tearDown()
    }

    func testInfoUpdateVersioningByAPNSToken() {
        initConfiguration(delay: .default)

        self.guaranteedDeliveryManager.canScheduleOperations = false
        let infoUpdateLimit = 50

        makeMockAsyncCallWithDelay(limit: infoUpdateLimit) { _ in
            let deviceToken = APNSTokenGenerator().generate()
            Mindbox.shared.apnsTokenUpdate(deviceToken: deviceToken)
        }

        delay(of: .default)

        do {
            let events = try self.databaseRepository.query(fetchLimit: infoUpdateLimit)
            XCTAssertNotEqual(events.count, 0)
            XCTAssertEqual(events.count, infoUpdateLimit)

            events.forEach {
                XCTAssertTrue($0.type == .infoUpdated)
            }

            events
                .sorted { $0.dateTimeOffset > $1.dateTimeOffset }
                .compactMap { BodyDecoder<MobileApplicationInfoUpdated>(decodable: $0.body)?.body }
                .enumerated()
                .makeIterator()
                .forEach { offset, element in
                    XCTAssertEqual(offset + 1, element.version, "Element version mismatch at offset \(offset + 1)")
                }
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testInfoUpdateVersioningByRequestAuthorization() {
        initConfiguration(delay: .default)

        self.guaranteedDeliveryManager.canScheduleOperations = false
        let infoUpdateLimit = 50

        makeMockSequentialCall(limit: infoUpdateLimit) { index in
            Mindbox.shared.notificationsRequestAuthorization(granted: index % 2 == 0)
        }

        delay(of: .default)

        do {
            let events = try self.databaseRepository.query(fetchLimit: infoUpdateLimit)
            XCTAssertNotEqual(events.count, 0)
            XCTAssertEqual(events.count, infoUpdateLimit)

            events.forEach({
                XCTAssertTrue($0.type == .infoUpdated)
            })
            events
                .sorted { $0.dateTimeOffset > $1.dateTimeOffset }
                .compactMap { BodyDecoder<MobileApplicationInfoUpdated>(decodable: $0.body)?.body }
                .enumerated()
                .makeIterator()
                .forEach { offset, element in
                    XCTAssertEqual(offset + 1, element.version, "Element version mismatch at offset \(offset + 1)")
                }
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
}

private extension VersioningTestCase {

    enum DelayTime {
        case `default`
        case custom(DispatchTimeInterval)

        var dispatchTime: DispatchTime {
            switch self {
            case .default:
                    .now() + .seconds(3) + .milliseconds(500)
            case .custom(let interval):
                    .now() + interval
            }
        }

        var timeInterval: TimeInterval {
            switch self {
            case .default:
                return 3.5 // 1.5 секунды
            case .custom(let interval):
                switch interval {
                case .seconds(let seconds):
                    return TimeInterval(seconds)
                case .milliseconds(let milliseconds):
                    return TimeInterval(milliseconds) / 1000
                case .microseconds(let microseconds):
                    return TimeInterval(microseconds) / 1_000_000
                case .nanoseconds(let nanoseconds):
                    return TimeInterval(nanoseconds) / 1_000_000_000
                case .never:
                    fatalError("Never DispatchTimeInterval case")
                @unknown default:
                    fatalError("Unknown DispatchTimeInterval case")
                }
            }
        }
    }

    func initConfiguration(delay of: DelayTime) {
        let delayExpectation = expectation(description: "Delay for initialization")

        initConfiguration()

        DispatchQueue.main.asyncAfter(deadline: of.dispatchTime) {
            delayExpectation.fulfill()
        }

        wait(for: [delayExpectation], timeout: of.timeInterval * 2)
    }

    func initConfiguration() {
        let configuration = try! MBConfiguration(
            endpoint: "mpush-test-iOS-test",
            domain: "api.mindbox.ru",
            previousInstallationId: "",
            previousDeviceUUID: UUID().uuidString,
            subscribeCustomerIfCreated: true
        )
        Mindbox.shared.initialization(configuration: configuration)
    }

    func makeMockAsyncCallWithDelay(limit: Int, mockSDKCall: @escaping ((Int) -> Void)) {
        let dispatchGroup = DispatchGroup()

        for index in 1...limit {
            dispatchGroup.enter()
            DispatchQueue.global().async {
                mockSDKCall(index)
                dispatchGroup.leave()
            }
        }

        // Явное ожидание завершения всех задач
        let result = dispatchGroup.wait(timeout: .now() + TimeInterval(limit / 2))
        XCTAssertEqual(result, .success, "Timeout while waiting for async calls")

        // Проверяем, что все вызовы произошли
        XCTAssertEqual(dispatchGroup.wait(timeout: .now()), .success, "Not all calls completed")
    }

    func makeMockSequentialCall(limit: Int, mockSDKCall: @escaping ((Int) -> Void)) {
        let serialQueue = DispatchQueue(label: "com.Mindbox.testInfoUpdateVersioning.serial")

        for index in 1...limit {
            serialQueue.sync {
                mockSDKCall(index)
            }
        }
    }

    func makeMockAsyncCall(limit: Int, mockSDKCall: @escaping ((Int) -> Void)) {
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

    func delay(of: DelayTime) {
        let delayExpectation = expectation(description: "Delay")

        DispatchQueue.main.asyncAfter(deadline: of.dispatchTime) {
            delayExpectation.fulfill()
        }

        wait(for: [delayExpectation], timeout: of.timeInterval * 2)
    }
}
