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
    
    var container = try! TestDependencyProvider()
    
    var sessionTemporaryStorage: SessionTemporaryStorage {
        container.sessionTemporaryStorage
    }
    
    var persistenceStorage: PersistenceStorage {
        container.persistenceStorage
    }
    
    var networkFetcher: NetworkFetcher {
        container.instanceFactory.makeNetworkFetcher()
    }
    
    var imageDownloader: ImageDownloader {
        container.imageDownloader
    }
    
    private var mapper: InAppConfigutationMapper!
    private let configStub = InAppConfigStub()
    private let targetingChecker: InAppTargetingCheckerProtocol = InAppTargetingChecker()
    private var shownInAppsIds: Set<String>!
    
    override func setUp() {
        super.setUp()
        mapper = InAppConfigutationMapper(geoService: container.geoService,
                                          segmentationService: container.segmentationSevice,
                                          customerSegmentsAPI: .live,
                                          inAppsVersion: 1,
                                          targetingChecker: targetingChecker,
                                          sessionTemporaryStorage: sessionTemporaryStorage,
                                          persistenceStorage: persistenceStorage,
                                          sdkVersionValidator: container.sdkVersionValidator,
                                          imageDownloadService: container.imageDownloadService,
                                          abTestDeviceMixer: container.abTestDeviceMixer)
        shownInAppsIds = Set(persistenceStorage.shownInAppsIds ?? [])
    }
    
    func test_config_valid_to_parse() throws {
        let response = try getConfig(name: "InappConfigResponseValid")
        
        let inapps: [InApp]? = [.init(id: "6f93e2ef-0615-4e63-9c80-24bcb9e83b83",
                                      sdkVersion: SdkVersion(min: 4, max: nil),
                                      targeting: .and(AndTargeting(nodes: [.true(TrueTargeting())])),
                                      form: InApp.InAppFormVariants(variants: [.init(imageUrl: "1",
                                                                                     redirectUrl: "2",
                                                                                     intentPayload: "3",
                                                                                     type: "simpleImage")]))]
        
        let abTestObject1 = ABTest.ABTestVariant.ABTestObject(
            type: .inapps,
            kind: .all,
            inapps: ["inapp1", "inapp2"]
        )
        
        // Создаем структуры ABTestVariant
        let abTestVariant1 = ABTest.ABTestVariant(
            id: "1", modulus: ABTest.ABTestVariant.Modulus(lower: 0, upper: 50),
            objects: [abTestObject1]
        )
        
        let abTestVariant2 = ABTest.ABTestVariant(
            id: "2", modulus: ABTest.ABTestVariant.Modulus(lower: 50, upper: 100),
            objects: [abTestObject1]
        )
        let abtests: [ABTest]? = [.init(id: "id123",
                                        sdkVersion: .init(min: 1, max: nil),
                                        salt: "salt123",
                                        variants: [abTestVariant1,
                                                   abTestVariant2]),
        ]
        
        let monitoring = Monitoring(logs: [.init(requestId: "request1",
                                                 deviceUUID: "device1",
                                                 from: "source1",
                                                 to: "destination1"),
                                           .init(requestId: "request2",
                                                 deviceUUID: "device2",
                                                 from: "source2",
                                                 to: "destination2")])
        
        let settings = Settings(operations: .init(viewProduct: .init(systemName: "product"),
                                                  viewCategory: .init(systemName: "category"),
                                                  setCart: .init(systemName: "cart")))
        
        XCTAssertEqual(response.inapps, inapps)
        XCTAssertEqual(response.abtests, abtests)
        XCTAssertEqual(response.monitoring, monitoring)
        XCTAssertEqual(response.settings, settings)
    }
    
    func test_config_settings_invalid_to_parse() throws {
        let response = try getConfig(name: "InappConfigResponseSettingsInvalid")
        let inapps: [InApp]? = [.init(id: "6f93e2ef-0615-4e63-9c80-24bcb9e83b83",
                                      sdkVersion: SdkVersion(min: 4, max: nil),
                                      targeting: .and(AndTargeting(nodes: [.true(TrueTargeting())])),
                                      form: InApp.InAppFormVariants(variants: [.init(imageUrl: "1",
                                                                                     redirectUrl: "2",
                                                                                     intentPayload: "3",
                                                                                     type: "simpleImage")]))]
        
        XCTAssertEqual(response.inapps, inapps)
        // No systemName in Settings JSON
        XCTAssertNil(response.settings)
    }
    
    func test_config_monitoring_invalid_to_parse() throws {
        let response = try getConfig(name: "InappConfigResponseMonitoringInvalid")
        let inapps: [InApp]? = [.init(id: "6f93e2ef-0615-4e63-9c80-24bcb9e83b83",
                                      sdkVersion: SdkVersion(min: 4, max: nil),
                                      targeting: .and(AndTargeting(nodes: [.true(TrueTargeting())])),
                                      form: InApp.InAppFormVariants(variants: [.init(imageUrl: "1",
                                                                                     redirectUrl: "2",
                                                                                     intentPayload: "3",
                                                                                     type: "simpleImage")]))]
        
        XCTAssertEqual(response.inapps, inapps)
        // No id in Monitoring JSON
        XCTAssertNil(response.monitoring)
    }
    
    func test_config_abtests_invalid_to_parse() throws {
        let response = try getConfig(name: "InappConfigResponseAbtestsInvalid")
        let inapps: [InApp]? = [.init(id: "6f93e2ef-0615-4e63-9c80-24bcb9e83b83",
                                      sdkVersion: SdkVersion(min: 4, max: nil),
                                      targeting: .and(AndTargeting(nodes: [.true(TrueTargeting())])),
                                      form: InApp.InAppFormVariants(variants: [.init(imageUrl: "1",
                                                                                     redirectUrl: "2",
                                                                                     intentPayload: "3",
                                                                                     type: "simpleImage")]))]
        
        XCTAssertEqual(response.inapps, inapps)
        // No id in Abtest JSON
        XCTAssertNil(response.abtests)
    }
}

private extension InAppConfigResponseTests {
    private func getConfig(name: String) throws -> ConfigResponse {
        let bundle = Bundle(for: InAppConfigResponseTests.self)
        let fileURL = bundle.url(forResource: name, withExtension: "json")!
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(ConfigResponse.self, from: data)
    }
}
