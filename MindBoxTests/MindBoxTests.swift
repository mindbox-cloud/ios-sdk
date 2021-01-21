//
//  MindBoxTests.swift
//  MindBoxTests
//
//  Created by Mikhail Barilov on 12.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import XCTest
@testable import MindBox

class MindBoxTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testOnInitCase() {

        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.

        let configuration = try! MBConfiguration(plistName: "TestConfig")
        MindBox.shared.initialization(configuration: configuration)

//        let exists = NSPredicate(format: "exists == 1")

//        expectation(for: exists, evaluatedWith: self, handler: nil)
//        waitForExpectations(timeout: 10, handler: nil)


    }

//    func testDefaultHeader() {
//
//        APIServiceConstant.defaultHeaders.forEach { (key, value) in
//
//            print("\(key):\(value)")
//        }
//    }

//    func testRequest() {
//        let req = MobileApplicationInstalledRequest(endpoint: "TheEndpoint", deviceUUID: UUID.init().uuidString, installationId: "TheInstallationId", apnsToken: "TheApnsToken")
//        APILogManager.req(req)
//    }

}
