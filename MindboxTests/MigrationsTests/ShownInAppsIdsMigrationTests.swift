//
//  ShownInAppsIdsMigrationTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 9/2/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

// swiftlint:disable force_try force_unwrapping

final class ShownInAppsIdsMigrationTests: XCTestCase {
    
    // MARK: Test data
    
    private let legacyIds = [
        "36920d7e-3c42-4194-9a11-b0b5c550460c",
        "37bed734-aa34-4c10-918b-873f67505d46"
    ]
    
    // MARK: SUT & collaborators
    
    private var migration: MigrationProtocol!
    private var storage: PersistenceStorage!
    
    // MARK: Test life-cycle
    
    @available(*, deprecated,
                message: "Suppress `deprecated` shownInAppsIds warning")
    override func setUp() {
        super.setUp()
        
        migration = ShownInAppsIDsMigration()
        
        storage = DI.injectOrFail(PersistenceStorage.self)
        storage.deviceUUID = "00000000-0000-0000-0000-000000000000"
        storage.installationDate      = Date()
        storage.shownInappsDictionary = nil
        storage.shownInAppsIds        = legacyIds
    }
    
    override func tearDown() {
        migration = nil
        storage   = nil
        super.tearDown()
    }
    
    // MARK: - Helper
    
    @available(*, deprecated,
                message: "Suppress `deprecated` shownInAppsIds warning")
    private func assertIdsWereMigrated(file: StaticString = #file, line: UInt = #line) {
        XCTAssertNil(storage.shownInAppsIds,
                     "Array must be nil after migration",
                     file: file, line: line)
        
        guard let dict = storage.shownInappsDictionary else {
            XCTFail("Dictionary must exist", file: file, line: line); return
        }
        
        XCTAssertEqual(dict.count, legacyIds.count,
                       "All elements must be migrated",
                       file: file, line: line)
        
        legacyIds.forEach { id in
            XCTAssertTrue(dict.keys.contains(id),
                          "Missing migrated key \(id)",
                          file: file, line: line)
        }
    }
}

// MARK: - Scenarios

@available(*, deprecated,
            message: "Suppress `deprecated` shownInAppsIds warning")
extension ShownInAppsIdsMigrationTests {
    
    func test_run_performsMigrationWhenNeeded() throws {
        XCTAssertTrue(migration.isNeeded)
        
        try migration.run()
        
        assertIdsWereMigrated()
        XCTAssertFalse(migration.isNeeded,
                       "`isNeeded` must flip to false after successful run()")
    }
    
    func test_run_skipsWhenAlreadyMigrated() throws {
        storage.shownInappsDictionary = legacyIds.reduce(into: [:]) { $0[$1] = Date() }
        storage.shownInAppsIds = nil
        XCTAssertFalse(migration.isNeeded)
        
        XCTAssertNoThrow(try migration.run())
        XCTAssertEqual(storage.shownInappsDictionary?.count, legacyIds.count)
        XCTAssertNil(storage.shownInAppsIds)
    }
    
    func test_run_isIdempotent() throws {
        try migration.run()
        assertIdsWereMigrated()
        
        XCTAssertNoThrow(try migration.run())
        XCTAssertEqual(storage.shownInappsDictionary?.count, legacyIds.count)
        XCTAssertNil(storage.shownInAppsIds)
    }
}
