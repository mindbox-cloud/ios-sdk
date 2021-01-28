//
//  MindBoxTests.swift
//  MindBoxTests
//
//  Created by Mikhail Barilov on 12.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import XCTest
@testable import MindBox

class MindBoxTests: XCTestCase, MindBoxDelegate {

    var mindBoxDidInstalledFlag: Bool = false
    var apnsTokenDidUpdatedFlag: Bool = false

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testOnInitCase() {

        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.

        MindBox.shared.delegate = self

        let configuration = try! MBConfiguration(plistName: "TestConfig")
        MindBox.shared.initialization(configuration: configuration)

        do {
            let exists = NSPredicate(format: "mindBoxDidInstalledFlag == true && apnsTokenDidUpdatedFlag == false")
            expectation(for: exists, evaluatedWith: self, handler: nil)
            waitForExpectations(timeout: 10, handler: nil)

            mindBoxDidInstalledFlag = false
            apnsTokenDidUpdatedFlag = false
        }

    	//        //        //        //        //        //		//        //        //        //        //        //

        MindBox.shared.initialization(configuration: configuration)

        do {
            let exists = NSPredicate(format: "mindBoxDidInstalledFlag == false && apnsTokenDidUpdatedFlag == true")
            expectation(for: exists, evaluatedWith: self, handler: nil)
            waitForExpectations(timeout: 10, handler: nil)

            mindBoxDidInstalledFlag = false
            apnsTokenDidUpdatedFlag = false
        }

        let persistensStorage: IPersistenceStorage = resolver.resolveOrDie()

        persistensStorage.resetStorage()

    }


    // MARK: - MindBoxDelegate

    func mindBoxDidInstalled() {
        mindBoxDidInstalledFlag = true
    }

    func mindBoxInstalledFailed(error: MindBox.Errors) {

    }

    func apnsTokenDidUpdated() {
        apnsTokenDidUpdatedFlag = true
    }
}
