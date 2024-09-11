//
//  ConfigParsingTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 9/11/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

fileprivate enum Config: String, Configurable {
    typealias DecodeType = ConfigResponse
    
    case configWithSettings = "ConfigWithSettingsABTestsMonitoringInapps"
}

final class ConfigParsingTests: XCTestCase {
    
    func testSuccessfullyParseAll() throws {
        let config = try! Config.configWithSettings.getConfig()
        XCTAssertNotNil(config.inapps, "Must NOT be nil")
        XCTAssertNotNil(config.abtests, "Must NOT be nil")
        XCTAssertNotNil(config.settings, "Must NOT be nil")
        XCTAssertNotNil(config.monitoring, "Must NOT be nil")
    }
}
