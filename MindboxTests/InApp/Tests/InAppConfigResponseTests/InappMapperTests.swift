//
//  InappMapperTests.swift
//  MindboxTests
//
//  Created by vailence on 14.11.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

// swiftlint:disable all

class InappRemainingTargetingTests: XCTestCase {

    private var targetingChecker: InAppTargetingCheckerProtocol!
    private var mockDataFacade: MockInAppConfigurationDataFacade!
    private var mapper: InappMapperProtocol!
    private var persistenceStorage: PersistenceStorage!

    override func setUp() {
        super.setUp()
        SessionTemporaryStorage.shared.erase()
        targetingChecker = DI.injectOrFail(InAppTargetingCheckerProtocol.self)

        let databaseRepository = DI.injectOrFail(MBDatabaseRepository.self)
        try! databaseRepository.erase()

        mockDataFacade = DI.injectOrFail(InAppConfigurationDataFacadeProtocol.self) as? MockInAppConfigurationDataFacade
        mockDataFacade.cleanTargetingArray()

        mapper = DI.injectOrFail(InappMapperProtocol.self)
        persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        persistenceStorage.shownInappsDictionary = [:]
    }

    override func tearDown() {
        mockDataFacade = nil
        targetingChecker = nil
        mapper = nil
        super.tearDown()
    }

    func test_InappTrue_NotShownBefore() { // 1
        let expectation = XCTestExpectation(description: "Waiting for sendRemainingInappsTargeting to complete")

        let config = getConfig(name: "1-Targeting")
        mapper.handleInapps(nil, config) { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
        targetingShow(id: "1")
        targetingEqual(ids: ["1"])
    }

    func test_TwoInappsTrue_NotShownBefore() { // 3
        let expectation = XCTestExpectation(description: "Waiting for sendRemainingInappsTargeting to complete")

        let config = getConfig(name: "3-4-5-TargetingRequests")
        mapper.handleInapps(nil, config) { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
        targetingShow(id: "1")
        targetingEqual(ids: ["1", "2"])
    }

    func test_TwoInappsTrue_FirstShownBefore() { // 4
        let expectation = XCTestExpectation(description: "Waiting for sendRemainingInappsTargeting to complete")
        persistenceStorage.shownInappsDictionary = ["1": Date()]
        let config = getConfig(name: "3-4-5-TargetingRequests")
        mapper.handleInapps(nil, config) { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
        targetingShow(id: "2")
        targetingEqual(ids: ["2", "1"])
    }

    func test_TwoInappsTrue_BothAlreadyShown() { // 5
        let expectation = XCTestExpectation(description: "Waiting for sendRemainingInappsTargeting to complete")
        persistenceStorage.shownInappsDictionary = ["1": Date(),
                                                    "2": Date()]

        let config = getConfig(name: "3-4-5-TargetingRequests")
        mapper.handleInapps(nil, config) { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
        XCTAssertTrue(!SessionTemporaryStorage.shared.isPresentingInAppMessage)
        targetingEqual(ids: ["1", "2"])
    }

    func test_OneInappGeo_NotShownBefore() { // 7
        let expectation = XCTestExpectation(description: "Waiting for sendRemainingInappsTargeting to complete")
        let config = getConfig(name: "7-TargetingRequests")
        targetingChecker.geoModels = .init(city: 1, region: 2, country: 3)
        SessionTemporaryStorage.shared.geoRequestCompleted = true

        mapper.handleInapps(nil, config) { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
        targetingShow(id: "1")
        targetingEqual(ids: ["1"])
    }

    func test_OneTrue_OneGeo_NotShownBefore() { // 8
        let expectation = XCTestExpectation(description: "Waiting for sendRemainingInappsTargeting to complete")
        let config = getConfig(name: "8-TargetingRequests")
        targetingChecker.geoModels = .init(city: 1, region: 2, country: 3)
        SessionTemporaryStorage.shared.geoRequestCompleted = true
        mapper.handleInapps(nil, config) { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
        targetingShow(id: "1")
        targetingEqual(ids: ["1", "2"])
    }

    func test_TrueShown_OperationTest_TrueNotShown_Geo_Segment() { // 9
        let expectationForsendRemainingInappsTargeting = XCTestExpectation(description: "Waiting for first sendRemainingInappsTargeting to complete")
        let expectationForhandleInapps = XCTestExpectation(description: "Waiting for handleInapps to complete")
        persistenceStorage.shownInappsDictionary = ["1": Date()]

        let config = getConfig(name: "9-TargetingRequests")
        targetingChecker.geoModels = .init(city: 1, region: 2, country: 3)
        SessionTemporaryStorage.shared.geoRequestCompleted = true

        targetingChecker.checkedSegmentations = [.init(segmentation: .init(ids: .init(externalId: "0000000")), segment: nil)]
        SessionTemporaryStorage.shared.checkSegmentsRequestCompleted = true

        mapper.handleInapps(nil, config) { _ in
            expectationForsendRemainingInappsTargeting.fulfill()
        }

        wait(for: [expectationForsendRemainingInappsTargeting], timeout: 1)

        targetingShow(id: "3")
        targetingEqual(ids: ["3", "1", "4", "5"])

        mockDataFacade.cleanTargetingArray()

        let event = ApplicationEvent(name: "test", model: nil)
        mapper.handleInapps(event, config) { _ in
            expectationForhandleInapps.fulfill()
        }

        wait(for: [expectationForhandleInapps], timeout: 1)
        targetingEqual(ids: ["2"])
    }

    func test_OneInappTwoOperations1OR2() { // 14
        let expectationTest = XCTestExpectation(description: "Operation 1")
        let expectationTest2 = XCTestExpectation(description: "Operation 2")

        let config = getConfig(name: "14-TargetingRequests")
        let testEvent = ApplicationEvent(name: "1", model: nil)
        mapper.handleInapps(testEvent, config) { _ in
            expectationTest.fulfill()
        }

        wait(for: [expectationTest], timeout: 1)
        targetingShow(id: "1")
        targetingEqual(ids: ["1"])

        mockDataFacade.cleanTargetingArray()

        let test2Event = ApplicationEvent(name: "2", model: nil)
        mapper.handleInapps(test2Event, config) { _ in
            expectationTest2.fulfill()
        }

        wait(for: [expectationTest2], timeout: 1)
        targetingEqual(ids: ["1"])
    }

    func test_OneInappForOperationAndSegment() { // 15
        let expectationTest = XCTestExpectation(description: "Operation 1")
        let expectationTest2 = XCTestExpectation(description: "Operation 2")

        targetingChecker.checkedSegmentations = [.init(segmentation: .init(ids: .init(externalId: "0000000")), segment: nil)]
        SessionTemporaryStorage.shared.checkSegmentsRequestCompleted = true

        let config = getConfig(name: "15-Targeting")
        mapper.handleInapps(nil, config) { _ in
            expectationTest.fulfill()
        }

        wait(for: [expectationTest], timeout: 1)
        targetingEqual(ids: [])

        mockDataFacade.cleanTargetingArray()

        let test2Event = ApplicationEvent(name: "test", model: nil)
        mapper.handleInapps(test2Event, config) { _ in
            expectationTest2.fulfill()
        }

        wait(for: [expectationTest2], timeout: 1)
        targetingShow(id: "1")
        targetingEqual(ids: ["1"])
    }

    func test_True_OperationTest() { // 16
        let expectationTrue = XCTestExpectation(description: "True")
        let expectationTest = XCTestExpectation(description: "Operation test")
        let expectationTestAgain = XCTestExpectation(description: "Operation test again")

        let config = getConfig(name: "16-17-TargetingRequests")
        mapper.handleInapps(nil, config) { _ in
            expectationTrue.fulfill()
        }

        wait(for: [expectationTrue], timeout: 1)
        targetingShow(id: "1")
        targetingEqual(ids: ["1"])

        mockDataFacade.cleanTargetingArray()

        let testEvent = ApplicationEvent(name: "test", model: nil)
        mapper.handleInapps(testEvent, config) { _ in
            expectationTest.fulfill()
        }

        wait(for: [expectationTest], timeout: 1)
        targetingEqual(ids: ["2"])

        mockDataFacade.cleanTargetingArray()

        let testEventAgain = ApplicationEvent(name: "test", model: nil)
        mapper.handleInapps(testEventAgain, config) { _ in
            expectationTestAgain.fulfill()
        }

        wait(for: [expectationTestAgain], timeout: 1)
        targetingEqual(ids: ["2"])
    }

    func test_unknownInapp_lowerSDK_trueInapp() { // 27
        let expectation = XCTestExpectation(description: "Waiting for sendRemainingInappsTargeting to complete")
        let config = getConfig(name: "27-TargetingRequests")
        mapper.handleInapps(nil, config) { _ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
        targetingEqual(ids: ["3"])
    }

    func test_fourInappsWithABTests_variant1() { // 31 - 1
        let expectation = XCTestExpectation(description: "Waiting for sendRemainingInappsTargeting to complete")
        let expectationTestAgain = XCTestExpectation(description: "Operation test again")
        let expectationForArray = XCTestExpectation(description: "Waiting for sendRemainingInappsTargeting to complete")

        let config = getConfig(name: "31-TargetingRequests")
        persistenceStorage.deviceUUID = "40909d27-4bef-4a8d-9164-6bfcf58ecc76" // 1 вариант
        targetingChecker.geoModels = .init(city: 1, region: 2, country: 3)
        SessionTemporaryStorage.shared.geoRequestCompleted = true

        mapper.handleInapps(nil, config) { _ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
            expectationForArray.fulfill()
        })

        wait(for: [expectationForArray], timeout: 3)
        targetingEqual(ids: ["1", "2", "3"])

        mockDataFacade.cleanTargetingArray()

        let testEventAgain = ApplicationEvent(name: "test", model: nil)
        mapper.handleInapps(testEventAgain, config) { _ in
            expectationTestAgain.fulfill()
        }

        wait(for: [expectationTestAgain], timeout: 3)
        targetingEqual(ids: ["4"])
    }

    func test_A_fourInappsWithABTests_variant2() { // 31 - 2
        let expectation = XCTestExpectation(description: "Waiting for sendRemainingInappsTargeting to complete")
        let expectationTestAgain = XCTestExpectation(description: "Operation test again")
        let expectationForArray = XCTestExpectation(description: "Waiting for sendRemainingInappsTargeting to complete")

        let config = getConfig(name: "31-TargetingRequests")
        persistenceStorage.deviceUUID = "b4e0f767-fe8f-4825-9772-f1162f2db52d" // 2 вариант
        targetingChecker.geoModels = .init(city: 1, region: 2, country: 3)
        SessionTemporaryStorage.shared.geoRequestCompleted = true

        mapper.handleInapps(nil, config) { _ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
            expectationForArray.fulfill()
        })

        wait(for: [expectationForArray], timeout: 3)
        targetingEqual(ids: ["1", "2", "3"])

        mockDataFacade.cleanTargetingArray()

        let testEventAgain = ApplicationEvent(name: "test", model: nil)
        mapper.handleInapps(testEventAgain, config) { _ in

            expectationTestAgain.fulfill()
        }

        wait(for: [expectationTestAgain], timeout: 3)
        targetingEqual(ids: ["4"])
    }

    func test_fourInappsWithABTests_variant3() {
        let expectation = XCTestExpectation(description: "Waiting for sendRemainingInappsTargeting to complete")
        let expectationTestAgain = XCTestExpectation(description: "Operation test again")
        let expectationForArray = XCTestExpectation(description: "Waiting for sendRemainingInappsTargeting to complete")

        let config = getConfig(name: "31-TargetingRequests")

        persistenceStorage.deviceUUID = "55fbd965-c658-47a8-8786-d72ba79b38a2" // 3 вариант
        targetingChecker.geoModels = .init(city: 1, region: 2, country: 3)
        SessionTemporaryStorage.shared.geoRequestCompleted = true
        mapper.handleInapps(nil, config) { _ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
            expectationForArray.fulfill()
        })

        wait(for: [expectationForArray], timeout: 3)
        targetingEqual(ids: ["1", "2", "3"])

        mockDataFacade.cleanTargetingArray()

        let testEventAgain = ApplicationEvent(name: "test", model: nil)
        mapper.handleInapps(testEventAgain, config) { _ in
            expectationTestAgain.fulfill()
        }

        wait(for: [expectationTestAgain], timeout: 2)
        targetingEqual(ids: ["4"])
    }

    func test_geoFitOrTest_OperationTest_OperationTest_OperationTest2_Geo() { // 44
        let expectation = XCTestExpectation(description: "Waiting for sendRemainingInappsTargeting to complete")
        let config = getConfig(name: "44-Targeting")
        targetingChecker.geoModels = .init(city: 1, region: 2, country: 3)
        SessionTemporaryStorage.shared.geoRequestCompleted = true
        mapper.handleInapps(nil, config) { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)

        targetingShow(id: "1")
        targetingEqual(ids: ["1", "5"])

        mockDataFacade.cleanTargetingArray()

        let expectationTestAgain = XCTestExpectation(description: "Operation test again")
        let testEvent = ApplicationEvent(name: "test", model: nil)

        mapper.handleInapps(testEvent, config) { _ in
            expectationTestAgain.fulfill()
        }

        wait(for: [expectationTestAgain], timeout: 1)
        targetingEqual(ids: ["1", "2", "3"])

        mockDataFacade.cleanTargetingArray()

        let expectationTest2 = XCTestExpectation(description: "Operation test2 ")
        let testEvent2 = ApplicationEvent(name: "test2", model: nil)

        mapper.handleInapps(testEvent2, config) { _ in
            expectationTest2.fulfill()
        }

        wait(for: [expectationTest2], timeout: 1)
        targetingEqual(ids: ["4"])
    }

    func test_geo_OperationTest_OperationTest_OperationTest2_geoFitOrTest() { // 45
        let expectation = XCTestExpectation(description: "Waiting for sendRemainingInappsTargeting to complete")
        let config = getConfig(name: "45-Targeting")
        targetingChecker.geoModels = .init(city: 1, region: 2, country: 3)
        SessionTemporaryStorage.shared.geoRequestCompleted = true
        mapper.handleInapps(nil, config) { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)

        targetingShow(id: "1")
        targetingEqual(ids: ["1", "5"])

        mockDataFacade.cleanTargetingArray()

        let expectationTestAgain = XCTestExpectation(description: "Operation test again")
        let testEvent = ApplicationEvent(name: "test", model: nil)

        mapper.handleInapps(testEvent, config) { _ in
            expectationTestAgain.fulfill()
        }

        wait(for: [expectationTestAgain], timeout: 1)
        targetingEqual(ids: ["2", "3", "5"])

        mockDataFacade.cleanTargetingArray()

        let expectationTest2 = XCTestExpectation(description: "Operation test2 ")
        let testEvent2 = ApplicationEvent(name: "test2", model: nil)

        mapper.handleInapps(testEvent2, config) { _ in
            expectationTest2.fulfill()
        }

        wait(for: [expectationTest2], timeout: 1)
        targetingEqual(ids: ["4"])
    }

    func test_geoFitOrTest_OperationTest_OperationTest_OperationTest2_geoFitOrTest() { // 46
        let expectation = XCTestExpectation(description: "Waiting for sendRemainingInappsTargeting to complete")
        let config = getConfig(name: "46-Targeting")
        targetingChecker.geoModels = .init(city: 1, region: 2, country: 3)
        SessionTemporaryStorage.shared.geoRequestCompleted = true
        mapper.handleInapps(nil, config) { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)

        targetingShow(id: "1")
        targetingEqual(ids: ["1", "5"])

        mockDataFacade.cleanTargetingArray()

        let expectationTestAgain = XCTestExpectation(description: "Operation test again")
        let testEvent = ApplicationEvent(name: "test", model: nil)

        mapper.handleInapps(testEvent, config) { _ in
            expectationTestAgain.fulfill()
        }

        wait(for: [expectationTestAgain], timeout: 1)
        targetingEqual(ids: ["1", "2", "3", "5"])

        mockDataFacade.cleanTargetingArray()

        let expectationTest2 = XCTestExpectation(description: "Operation test2 ")
        let testEvent2 = ApplicationEvent(name: "test2", model: nil)

        mapper.handleInapps(testEvent2, config) { _ in
            expectationTest2.fulfill()
        }

        wait(for: [expectationTest2], timeout: 1)
        targetingEqual(ids: ["4"])
    }

    private func getConfig(name: String) -> ConfigResponse {
        let bundle = Bundle(for: InappRemainingTargetingTests.self)
        let fileURL = bundle.url(forResource: name, withExtension: "json")!
        let data = try! Data(contentsOf: fileURL)
        return try! JSONDecoder().decode(ConfigResponse.self, from: data)
    }
}

private extension InappRemainingTargetingTests {
    func targetingShow(id: String) {
        XCTAssertTrue(mockDataFacade.showArray.contains(id), "ID \(id) is expected to be shown")
    }

    func targetingEqual(ids: [String]) {
        XCTAssertEqual(Set(mockDataFacade.targetingArray), Set(ids), "Targeting array does not match the expected IDs")
    }
}
