//
//  InAppConfigResponseTests.swift
//  MindboxTests
//
//  Created by Максим Казаков on 12.10.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation
import XCTest
@testable import Mindbox

class InAppConfigResponseTests: XCTestCase {
    
    private let networkFetcher: NetworkFetcher = MockNetworkFetcher()
    private let targetingChecker: InAppTargetingCheckerProtocol = InAppTargetingChecker()
    private let sessionTemporaryStorage = SessionTemporaryStorage()

    func test_2InApps_oneFitsInAppsSdkVersion_andOneDoesnt() throws {
        let response = try getConfigWithTwoInapps()
        var config: InAppConfig?
        let expectation = expectation(description: "test_2InApps_oneFitsInAppsSdkVersion_andOneDoesnt")
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live,
                                         inAppsVersion: 1,
                                         targetingChecker: targetingChecker,
                                         networkFetcher: networkFetcher,
                                         sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(nil, response, { result in
                config = result
                expectation.fulfill()
            })
        
        waitForExpectations(timeout: 5)
        
        let expected = InAppConfig(inAppsByEvent: [
            .start: [
                .init(id: "00000000-0000-0000-0000-000000000001",
                      formDataVariants: [
                        .init(imageUrl: "https://s3-symbol-logo.tradingview.com/true-corporation-public-company-limited--600.png",
                              redirectUrl: "",
                              intentPayload: "")])]
        ])
        
        XCTAssertEqual(expected, config)
    }

    func test_2InApps_bothFitInAppsSdkVersion() throws {
        let response = try getConfigWithTwoInapps()
        var config: InAppConfig?
        let expectation = expectation(description: "test_2InApps_bothFitInAppsSdkVersion")
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live,
                                         inAppsVersion: 3,
                                         targetingChecker: targetingChecker,
                                         networkFetcher: networkFetcher,
                                         sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(nil, response, { result in
                config = result
                expectation.fulfill()
            })
        
        waitForExpectations(timeout: 5)

        let expected = InAppConfig(inAppsByEvent: [
            .start: [
                .init(id: "00000000-0000-0000-0000-000000000001",
                      formDataVariants: [
                        .init(imageUrl: "https://s3-symbol-logo.tradingview.com/true-corporation-public-company-limited--600.png",
                              redirectUrl: "",
                              intentPayload: "")]),
                .init(id: "00000000-0000-0000-0000-000000000002",
                      formDataVariants: [
                        .init(imageUrl: "https://s3-symbol-logo.tradingview.com/true-corporation-public-company-limited--600.png",
                              redirectUrl: "",
                              intentPayload: "")])]
        ])
 
        XCTAssertEqual(expected, config)
    }

    func test_invalidInApps() throws {
        let response = try getConfigWithInvalidInapps()
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_invalidInApps")
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live,
                                         inAppsVersion: 3,
                                         targetingChecker: targetingChecker,
                                         networkFetcher: networkFetcher,
                                         sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(nil, response, { result in
                config = result
                expectation.fulfill()
            })
        
        waitForExpectations(timeout: 5)
        
        guard let config = config else { return }
        XCTAssertEqual(1, config.inAppsByEvent.count)
        let inappsForStartEvent = config.inAppsByEvent[.start]!
        XCTAssertEqual(1, inappsForStartEvent.count)
        let onlyValidInapp = inappsForStartEvent.first!
        XCTAssertEqual(onlyValidInapp.id, "00000000-0000-0000-0000-000000000002")
    }

    func test_2InApps_bothDontFitInAppsSdkVersion() throws {
        let response = try getConfigWithTwoInapps()
        var config: InAppConfig?
        let expectation = self.expectation(description: "test_2InApps_bothDontFitInAppsSdkVersion")
        let _ = InAppConfigutationMapper(customerSegmentsAPI: .live,
                                         inAppsVersion: 0,
                                         targetingChecker: targetingChecker,
                                         networkFetcher: networkFetcher,
                                         sessionTemporaryStorage: sessionTemporaryStorage)
            .mapConfigResponse(nil, response, { result in
                config = result
                expectation.fulfill()
            })
        
        let expected = InAppConfig(inAppsByEvent: [:])
        
        waitForExpectations(timeout: 5)
        XCTAssertEqual(expected, config)
    }
    
    func test_operation_happyFlow() throws {
            let response = try getConfigWithOperations()
            var config: InAppConfig?
            let expectation = self.expectation(description: "test_operations_happyFlow")
            let _ = InAppConfigutationMapper(customerSegmentsAPI: .live,
                                             inAppsVersion: 4,
                                             targetingChecker: targetingChecker,
                                             networkFetcher: networkFetcher,
                                             sessionTemporaryStorage: sessionTemporaryStorage)
                .mapConfigResponse("TestPushok", response) { result in
                    config = result
                    expectation.fulfill()
                }
            
            let expected = InAppConfig(inAppsByEvent: [
                .applicationEvent("TestPushok"): [
                    .init(id: "00000000-0000-0000-0000-000000000001",
                          formDataVariants: [
                            .init(imageUrl: "https://s3-symbol-logo.tradingview.com/true-corporation-public-company-limited--600.png",
                                  redirectUrl: "",
                                  intentPayload: "")])]
            ])
            waitForExpectations(timeout: 5)
            XCTAssertEqual(expected, config)
        }
        
        func test_operation_empty_operatonName() throws {
            let response = try getConfigWithOperations()
            var config: InAppConfig?
            let expectation = self.expectation(description: "test_operations_happyFlow")
            let _ = InAppConfigutationMapper(customerSegmentsAPI: .live,
                                             inAppsVersion: 4,
                                             targetingChecker: targetingChecker,
                                             networkFetcher: networkFetcher,
                                             sessionTemporaryStorage: sessionTemporaryStorage)
                .mapConfigResponse(nil, response) { result in
                    config = result
                    expectation.fulfill()
                }
            
            let expected = InAppConfig(inAppsByEvent: [:])
            waitForExpectations(timeout: 5)
            
            XCTAssertEqual(expected, config)
        }
        
        func test_operation_wrong_operatonName() throws {
            let response = try getConfigWithOperations()
            var config: InAppConfig?
            let expectation = self.expectation(description: "test_operations_happyFlow")
            let _ = InAppConfigutationMapper(customerSegmentsAPI: .live, inAppsVersion: 4, targetingChecker: targetingChecker, networkFetcher: networkFetcher, sessionTemporaryStorage: sessionTemporaryStorage)
                .mapConfigResponse("WrongOperationName", response) { result in
                    config = result
                    expectation.fulfill()
                }
            
            let expected = InAppConfig(inAppsByEvent: [:])
            waitForExpectations(timeout: 5)
            
            XCTAssertEqual(expected, config)
        }
}

private extension InAppConfigResponseTests {
    private func getConfigWithTwoInapps() throws -> InAppConfigResponse {
        let bundle = Bundle(for: InAppConfigResponseTests.self)
        let fileURL = bundle.url(forResource: "InAppConfiguration", withExtension: "json")!
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(InAppConfigResponse.self, from: data)
    }

    private func getConfigWithInvalidInapps() throws -> InAppConfigResponse {
        let bundle = Bundle(for: InAppConfigResponseTests.self)
        let fileURL = bundle.url(forResource: "InAppConfigurationInvalid", withExtension: "json")!
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(InAppConfigResponse.self, from: data)
    }
    
    private func getConfigWithOperations() throws -> InAppConfigResponse {
        let bundle = Bundle(for: InAppConfigResponseTests.self)
        let fileURL = bundle.url(forResource: "InAppConfigurationWithOperations", withExtension: "json")!
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(InAppConfigResponse.self, from: data)
    }
}
