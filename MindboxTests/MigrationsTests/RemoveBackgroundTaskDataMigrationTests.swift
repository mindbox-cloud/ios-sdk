//
//  RemoveBackgroundTaskDataMigrationTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 6/27/25.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

final class RemoveBackgroundTaskDataMigrationTests: XCTestCase {
    
    private var migration: MigrationProtocol!
    private var userDefaults: UserDefaults!
    private let userDefaultsSuiteName = "RemoveBackgroundTaskDataMigrationTests"
    
    private let key = "backgroundExecution"
    private let plistName = "BackgroundExecution.plist"
    
    override func setUp() {
        super.setUp()
        // Use an isolated UserDefaults suite for tests
        userDefaults = UserDefaults(suiteName: userDefaultsSuiteName)!
        userDefaults.removePersistentDomain(forName: userDefaultsSuiteName)
        MBPersistenceStorage.defaults = userDefaults
        
        removeStrayPlist()
        
        migration = RemoveBackgroundTaskDataMigration()
    }
    
    override func tearDown() {
        userDefaults.removePersistentDomain(forName: userDefaultsSuiteName)
        removeStrayPlist()
        super.tearDown()
    }
    
    // MARK: - Helpers
    
    private var documentsURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var fileURL: URL {
        documentsURL.appendingPathComponent(plistName)
    }
    
    private func createDummyFile() throws {
        // Simply create an empty file in Documents
        FileManager.default.createFile(atPath: fileURL.path, contents: Data(), attributes: nil)
    }
    
    private func removeStrayPlist() {
        let fm = FileManager.default
        let stray = fileURL
        try? fm.removeItem(at: stray)
    }
}

// MARK: - Scenarios

extension RemoveBackgroundTaskDataMigrationTests {
    
    func test_isNeeded_true_ifUserDefaultsHasKey() {
        // given
        userDefaults.set(Data(), forKey: key)
        
        // then
        XCTAssertTrue(migration.isNeeded)
    }
    
    func test_run_removesUserDefaultsKey() throws {
        // given
        userDefaults.set(Data(), forKey: key)
        XCTAssertTrue(migration.isNeeded)
        
        // when
        try migration.run()
        
        // then
        XCTAssertNil(userDefaults.object(forKey: key),
                     "The key should be removed from UserDefaults")
        XCTAssertFalse(migration.isNeeded,
                      "After removing the key, isNeeded should be false")
    }
    
    func test_isNeeded_true_ifFileExists() throws {
        // given
        try createDummyFile()
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        
        // then
        XCTAssertTrue(migration.isNeeded)
    }
    
    func test_run_removesFile() throws {
        // given
        try createDummyFile()
        XCTAssertTrue(migration.isNeeded)
        
        // when
        try migration.run()
        
        // then
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path),
                       "The file should be removed after run()")
        XCTAssertFalse(migration.isNeeded,
                       "After removing the file, isNeeded should be false")
    }
    
    func test_isNeeded_true_ifKeyAndFileExist() throws {
        // given
        userDefaults.set(Data(), forKey: key)
        try createDummyFile()
        XCTAssertTrue(migration.isNeeded)
        
        // when
        try migration.run()
        
        // then both should be removed
        XCTAssertNil(userDefaults.object(forKey: key),
                     "The key should be removed from UserDefaults when both key and file exist")
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path),
                       "The file should be removed from Documents when both key and file exist")
        XCTAssertFalse(migration.isNeeded,
                       "After removing both key and file, isNeeded should be false")
    }
    
    func test_run_idempotent_whenCalledTwice() throws {
        // given: ensure nothing to remove initially
        XCTAssertNil(userDefaults.object(forKey: key))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        
        // when: first run
        XCTAssertNoThrow(try migration.run())
        // second run
        XCTAssertNoThrow(try migration.run())
        
        // then: still nothing to remove and isNeeded remains false
        XCTAssertNil(userDefaults.object(forKey: key),
                     "After two runs, the key should remain removed")
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path),
                       "After two runs, the file should remain removed")
        XCTAssertFalse(migration.isNeeded,
                       "After two runs, isNeeded should remain false")
    }
    
    func test_isNeeded_false_ifNothingToRemove() {
        // ensure neither the key nor the file exist
        XCTAssertNil(userDefaults.object(forKey: key))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        
        // then
        XCTAssertFalse(migration.isNeeded)
        
        // and run() does not throw
        XCTAssertNoThrow(try migration.run())
    }
}
