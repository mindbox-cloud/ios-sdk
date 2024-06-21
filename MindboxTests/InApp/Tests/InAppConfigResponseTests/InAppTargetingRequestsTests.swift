//
//  InAppTargetingRequestsTests.swift
//  MindboxTests
//
//  Created by vailence on 04.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

class InAppTargetingRequestsTests: XCTestCase {

    var container: TestDependencyProvider!

    private var mockDataFacade: MockInAppConfigurationDataFacade!
    private var mapper: InAppConfigurationMapperProtocol!
    private var persistenceStorage: PersistenceStorage!
    
    private var targetingChecker: InAppTargetingCheckerProtocol!
    
    override func setUp() {
        super.setUp()
        container = try! TestDependencyProvider()
        SessionTemporaryStorage.shared.erase()
        targetingChecker = container.inAppTargetingChecker
        try! container.databaseRepository.erase()
        let tracker = InAppMessagesTracker(databaseRepository: container.databaseRepository)
        mockDataFacade = MockInAppConfigurationDataFacade(geoService: container.geoService,
                                                              segmentationService: container.segmentationSevice,
                                                              targetingChecker: targetingChecker, 
                                                              imageService: container.imageDownloadService,
                                                              tracker: tracker)
        mockDataFacade.clean()

        mapper = InAppConfigutationMapper(inappFilterService: container.inappFilterService,
                                          targetingChecker: targetingChecker,
                                          dataFacade: mockDataFacade)
        persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
    }
    
    override func tearDown() {
        container = nil
        mockDataFacade = nil
        targetingChecker = nil
        mapper = nil
        super.tearDown()
    }

    func test_TwoInappsTrue_NotShownBefore() {
        let expectation = XCTestExpectation(description: "Waiting for sendRemainingInappsTargeting to complete")
        do {
            let config = try getConfig(name: "3-4-5-TargetingRequests")
            mapper.mapConfigResponse(nil, config) { _ in
                self.mapper.sendRemainingInappsTargeting()
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 1)
            targetingContains("1", expectedToShow: true)
            targetingContains("2")
        } catch {
            XCTFail("Some error: \(error)")
        }
    }

    func test_TwoInappsTrue_FirstShownBefore() {
        let expectation = XCTestExpectation(description: "Waiting for sendRemainingInappsTargeting to complete")
        persistenceStorage.shownInAppsIds = ["1"]
        do {
            let config = try getConfig(name: "3-4-5-TargetingRequests")
            mapper.mapConfigResponse(nil, config) { _ in
                self.mapper.sendRemainingInappsTargeting()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 1)
            targetingContains("2")
            targetingContains("1")
        } catch {
            XCTFail("Some error: \(error)")
        }
    }
    
    func test_OneInappGeo_NotShownBefore() {
        let expectation = XCTestExpectation(description: "Waiting for sendRemainingInappsTargeting to complete")
        do {
            let config = try getConfig(name: "7-TargetingRequests")
            targetingChecker.geoModels = .init(city: 1, region: 2, country: 3)
            SessionTemporaryStorage.shared.geoRequestCompleted = true
            
            mapper.mapConfigResponse(nil, config) { _ in
                self.mapper.sendRemainingInappsTargeting()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 1)
            targetingContains("1", expectedToShow: true)
        } catch {
            print("Произошла ошибка: \(error)")
        }
    }
    
    func test_OneTrue_OneGeo_NotShownBefore() {
        let expectation = XCTestExpectation(description: "Waiting for sendRemainingInappsTargeting to complete")
        do {
            let config = try getConfig(name: "8-TargetingRequests")
            targetingChecker.geoModels = .init(city: 1, region: 2, country: 3)
            SessionTemporaryStorage.shared.geoRequestCompleted = true
            
            mapper.mapConfigResponse(nil, config) { _ in
                self.mapper.sendRemainingInappsTargeting()
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1)
            targetingContains("1", expectedToShow: true)
            targetingContains("2")
            
        } catch {
            print("Произошла ошибка: \(error)")
        }
    }
    
    func test_TrueShown_OperationTest_TrueNotShown_Geo_Segment() {
        let expectationForsendRemainingInappsTargeting = XCTestExpectation(description: "Waiting for first sendRemainingInappsTargeting to complete")
        let expectationForMapConfigResponse = XCTestExpectation(description: "Waiting for mapConfigResponse to complete")
            
        persistenceStorage.shownInAppsIds = ["1"]
        do {
            let config = try getConfig(name: "9-TargetingRequests")
            targetingChecker.geoModels = .init(city: 1, region: 2, country: 3)
            SessionTemporaryStorage.shared.geoRequestCompleted = true
            
            targetingChecker.checkedSegmentations = [.init(segmentation: .init(ids: .init(externalId: "0000000")), segment: nil)]
            SessionTemporaryStorage.shared.checkSegmentsRequestCompleted = true
            
            mapper.mapConfigResponse(nil, config) { _ in
                self.mapper.sendRemainingInappsTargeting()
                expectationForsendRemainingInappsTargeting.fulfill()
            }
            
            wait(for: [expectationForsendRemainingInappsTargeting], timeout: 1)
            targetingContains("3")
            targetingContains("1")
            targetingContains("4")
            targetingContains("5")
            
            mockDataFacade.clean()
            
            let event = ApplicationEvent(name: "test", model: nil)
            mapper.mapConfigResponse(event, config) { _ in
                self.mapper.sendRemainingInappsTargeting()
                expectationForMapConfigResponse.fulfill()
            }
            
            wait(for: [expectationForMapConfigResponse], timeout: 1)
            targetingEqual(["2"])
        } catch {
            print("Произошла ошибка: \(error)")
        }
    }
    
    func test_OneInappTwoOperations1OR2() {
        let expectationTest = XCTestExpectation(description: "Operation 1")
        let expectationTest2 = XCTestExpectation(description: "Operation 2")
            
        do {
            let config = try getConfig(name: "14-TargetingRequests")
            let testEvent = ApplicationEvent(name: "1", model: nil)
            mapper.mapConfigResponse(testEvent, config) { _ in
                self.mapper.sendRemainingInappsTargeting()
                expectationTest.fulfill()
            }
            
            wait(for: [expectationTest], timeout: 1)
            targetingContains("1", expectedToShow: true)
            
            mockDataFacade.clean()
            
            let test2Event = ApplicationEvent(name: "2", model: nil)
            mapper.mapConfigResponse(test2Event, config) { _ in
                self.mapper.sendRemainingInappsTargeting()
                expectationTest2.fulfill()
            }
            
            wait(for: [expectationTest2], timeout: 1)
            targetingEqual(["1"])
        } catch {
            print("Произошла ошибка: \(error)")
        }
    }
    
    func test_TrueShown_OperationTest() {
        let expectationTrue = XCTestExpectation(description: "True")
        let expectationTest = XCTestExpectation(description: "Operation test")
        let expectationTestAgain = XCTestExpectation(description: "Operation test again")
            
        persistenceStorage.shownInAppsIds = ["1"]
        
        do {
            let config = try getConfig(name: "16-17-TargetingRequests")
            mapper.mapConfigResponse(nil, config) { _ in
                self.mapper.sendRemainingInappsTargeting()
                expectationTrue.fulfill()
            }
            
            wait(for: [expectationTrue], timeout: 1)
            targetingContains("1")

            mockDataFacade.clean()
            
            let testEvent = ApplicationEvent(name: "test", model: nil)
            mapper.mapConfigResponse(testEvent, config) { _ in
                self.mapper.sendRemainingInappsTargeting()
                expectationTest.fulfill()
            }
            
            wait(for: [expectationTest], timeout: 1)
            targetingEqual(["2"])
            
            mockDataFacade.clean()
            
            let testEventAgain = ApplicationEvent(name: "test", model: nil)
            mapper.mapConfigResponse(testEventAgain, config) { _ in
                self.mapper.sendRemainingInappsTargeting()
                expectationTestAgain.fulfill()
            }
            
            wait(for: [expectationTestAgain], timeout: 1)
            targetingEqual(["2"])
        } catch {
            print("Произошла ошибка: \(error)")
        }
    }
    
    func test_unknownInapp_lowerSDK_trueInapp() {
        let expectation = XCTestExpectation(description: "Waiting for sendRemainingInappsTargeting to complete")
        do {
            let config = try getConfig(name: "27-TargetingRequests")
            
            mapper.mapConfigResponse(nil, config) { _ in
                self.mapper.sendRemainingInappsTargeting()
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1)
            targetingEqual(["3"])
            
        } catch {
            print("Произошла ошибка: \(error)")
        }
    }

    func test_fourInappsWithABTests_variant1() {
        let expectation = XCTestExpectation(description: "Waiting for sendRemainingInappsTargeting to complete")
        let expectationTestAgain = XCTestExpectation(description: "Operation test again")
        let expectationForArray = XCTestExpectation(description: "Waiting for sendRemainingInappsTargeting to complete")

        do {
            let config = try getConfig(name: "31-TargetingRequests")
            
            persistenceStorage.deviceUUID = "40909d27-4bef-4a8d-9164-6bfcf58ecc76" // 1 вариант
            
            targetingChecker.geoModels = .init(city: 1, region: 2, country: 3)
            SessionTemporaryStorage.shared.geoRequestCompleted = true
            
            mapper.mapConfigResponse(nil, config) { _ in
                self.mapper.sendRemainingInappsTargeting()
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 3)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
                expectationForArray.fulfill()
            })
            
            wait(for: [expectationForArray], timeout: 3)
            targetingContains("1")
            targetingContains("2")
            targetingContains("3")
            
            mockDataFacade.clean()
            
            let testEventAgain = ApplicationEvent(name: "test", model: nil)
            mapper.mapConfigResponse(testEventAgain, config) { _ in
                self.mapper.sendRemainingInappsTargeting()
                expectationTestAgain.fulfill()
            }
            
            wait(for: [expectationTestAgain], timeout: 3)
            targetingEqual(["4"])
            
        } catch {
            print("Произошла ошибка: \(error)")
        }
    }
    
    func test_A_fourInappsWithABTests_variant2() {
        let expectation = XCTestExpectation(description: "Waiting for sendRemainingInappsTargeting to complete")
        let expectationTestAgain = XCTestExpectation(description: "Operation test again")
        let expectationForArray = XCTestExpectation(description: "Waiting for sendRemainingInappsTargeting to complete")
        
        do {
            let config = try getConfig(name: "31-TargetingRequests")
            persistenceStorage.deviceUUID = "b4e0f767-fe8f-4825-9772-f1162f2db52d" // 2 вариант
            targetingChecker.geoModels = .init(city: 1, region: 2, country: 3)
            SessionTemporaryStorage.shared.geoRequestCompleted = true
            
            mapper.mapConfigResponse(nil, config) { _ in
                self.mapper.sendRemainingInappsTargeting()
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 3)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
                expectationForArray.fulfill()
            })
            
            wait(for: [expectationForArray], timeout: 3)
            targetingContains("1")
            targetingContains("2")
            targetingContains("3")
            
            mockDataFacade.clean()
            
            let testEventAgain = ApplicationEvent(name: "test", model: nil)
            mapper.mapConfigResponse(testEventAgain, config) { _ in
                self.mapper.sendRemainingInappsTargeting()
                expectationTestAgain.fulfill()
            }
            
            wait(for: [expectationTestAgain], timeout: 3)
            targetingEqual(["4"])
            
        } catch {
            print("Произошла ошибка: \(error)")
        }
    }
    
    func test_fourInappsWithABTests_variant3() {
        let expectation = XCTestExpectation(description: "Waiting for sendRemainingInappsTargeting to complete")
        let expectationTestAgain = XCTestExpectation(description: "Operation test again")
        let expectationForArray = XCTestExpectation(description: "Waiting for sendRemainingInappsTargeting to complete")

        do {
            let config = try getConfig(name: "31-TargetingRequests")
            
            persistenceStorage.deviceUUID = "55fbd965-c658-47a8-8786-d72ba79b38a2" // 3 вариант
            
            targetingChecker.geoModels = .init(city: 1, region: 2, country: 3)
            SessionTemporaryStorage.shared.geoRequestCompleted = true
            
            mapper.mapConfigResponse(nil, config) { _ in
                self.mapper.sendRemainingInappsTargeting()
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 3)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
                expectationForArray.fulfill()
            })
            
            wait(for: [expectationForArray], timeout: 3)
            targetingContains("1")
            targetingContains("2")
            targetingContains("3")
            
            mockDataFacade.clean()
            
            let testEventAgain = ApplicationEvent(name: "test", model: nil)
            mapper.mapConfigResponse(testEventAgain, config) { _ in
                self.mapper.sendRemainingInappsTargeting()
                expectationTestAgain.fulfill()
            }
            
            wait(for: [expectationTestAgain], timeout: 2)
            targetingEqual(["4"])
            
        } catch {
            print("Произошла ошибка: \(error)")
        }
    }
    
    private func getConfig(name: String) throws -> ConfigResponse {
        let bundle = Bundle(for: InAppTargetingRequestsTests.self)
        let fileURL = bundle.url(forResource: name, withExtension: "json")!
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(ConfigResponse.self, from: data)
    }

    func targetingContains(_ id: String, expectedToShow: Bool = false){
        XCTAssertTrue(mockDataFacade.targetingArray.contains(id), "ID \(id) is expected to be in targeting list")
        if expectedToShow {
            XCTAssertTrue(mockDataFacade.showArray.contains(id), "ID \(id) is expected to be shown")
        }
    }

    func targetingEqual(_ array: [String]) {
        XCTAssertEqual(mockDataFacade.targetingArray, array)
    }
}
