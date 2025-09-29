//
//  DataBaseLoading_StubDatabaseLoaderContractTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 9/29/25.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

final class DataBaseLoading_StubDatabaseLoaderContractTests: XCTestCase {

    private var loader: DatabaseLoading!

    override func setUp() {
        super.setUp()
        loader = StubDatabaseLoader()
    }

    override func tearDown() {
        loader = nil
        super.tearDown()
    }

    func test_loadPersistentContainer_throwsSpecificError() {
        XCTAssertThrowsError(try loader.loadPersistentContainer(), "StubLoader must throw on loadPersistentContainer()") { error in
            if let e = error as? MBDatabaseError {
                switch e {
                case .unableCreateDatabaseModel:
                    // ok
                    break
                default:
                    XCTFail("Expected .unableCreateDatabaseModel, got \(e)")
                }
            } else {
                XCTFail("Expected MBDatabaseError, got \(type(of: error)): \(error)")
            }
        }
    }

    func test_makeInMemoryContainer_throwsSpecificError() {
        XCTAssertThrowsError(try loader.makeInMemoryContainer(), "StubLoader must throw on makeInMemoryContainer()") { error in
            if let e = error as? MBDatabaseError {
                switch e {
                case .unableCreateDatabaseModel:
                    // ok
                    break
                default:
                    XCTFail("Expected .unableCreateDatabaseModel, got \(e)")
                }
            } else {
                XCTFail("Expected MBDatabaseError, got \(type(of: error)): \(error)")
            }
        }
    }

    func test_destroy_doesNotThrow() {
        XCTAssertNoThrow(try loader.destroy(), "StubLoader destroy() must not throw")
    }
}
