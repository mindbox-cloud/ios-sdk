//
//  MBConfigurationTest.swift
//  MindboxTests
//
//  Created by Mikhail Barilov on 29.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import XCTest
@testable import Mindbox

class MBConfigurationTestCase: XCTestCase {
    //Invalid
    let emptyDomainFile = "TestConfig_Invalid_1"
    let emptyEndpointFile = "TestConfig_Invalid_2"
    //Valid
    let emptyUUIDFile = "TestConfig_Invalid_3"
    let emptyIDDomainFile = "TestConfig_Invalid_4"

    override func setUpWithError() throws {


        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func test_MBConfiguration_should_not_throw() throws {
        try [
            emptyUUIDFile,
            emptyIDDomainFile
        ].forEach { (file) in
            XCTAssertNoThrow(try MBConfiguration(plistName: file), "")
        }
    }

    func test_MBConfiguration_should_throw() throws {
        try [
            emptyDomainFile,
            emptyEndpointFile,
        ].forEach { (file) in
            XCTAssertThrowsError(try MBConfiguration(plistName: file), "") { (error) in
                if let localizedError = error as? LocalizedError {
                    XCTAssertNotNil(localizedError.errorDescription)
                    XCTAssertNotNil(localizedError.failureReason)
                }
            }
        }


        XCTAssertNotNil(try? MBConfiguration(plistName: "TestConfig1"))
        XCTAssertNotNil(try? MBConfiguration(plistName: "TestConfig2"))
        XCTAssertNotNil(try? MBConfiguration(plistName: "TestConfig3"))
        XCTAssertNil(try? MBConfiguration(plistName: "file_that_|never_exist№%:,.;()(;.,:%№"))



    }


}
