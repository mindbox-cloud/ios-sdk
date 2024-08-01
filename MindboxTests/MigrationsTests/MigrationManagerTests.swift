//
//  MigrationManagerTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 7/30/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

final class MigrationManagerTests: XCTestCase {
    
    private var migrationManager: MigrationManagerProtocol!
    private var persistenceStorageMock: PersistenceStorage!
    
    override func setUp() {
        super.setUp()
        persistenceStorageMock = DI.injectOrFail(PersistenceStorage.self)
        persistenceStorageMock.deviceUUID = "00000000-0000-0000-0000-000000000000"
        persistenceStorageMock.installationDate = Date()
        persistenceStorageMock.configuration = .some(try! MBConfiguration(plistName: "TestConfig1"))
        
        let testMigrations: [MigrationProtocol] = [
            TestBaseMigration_1()
        ]
        
        migrationManager = MigrationManager(
            persistenceStorage: persistenceStorageMock,
            migrations: testMigrations,
            sdkVersionCode: 1
        )
    }
    
    override func tearDown() {
        migrationManager = nil
        persistenceStorageMock = nil
        super.tearDown()
    }
    
    func testProductionMigrations() {
        migrationManager = MigrationManager(persistenceStorage: persistenceStorageMock)
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 0)
        migrationManager.migrate()
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == MigrationConstants.sdkVersionCode)
    }
    
    func testPerformTestMigrationsButFirstInstallationAndSkipMigrations() {
        let testMigrations: [MigrationProtocol] = [
            TestBaseMigration_1()
        ]
        
        persistenceStorageMock.installationDate = nil
        
        migrationManager = MigrationManager(persistenceStorage: persistenceStorageMock,
                                            migrations: testMigrations, sdkVersionCode: 1)
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 0)
        migrationManager.migrate()
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 1)
        XCTAssertNotNil(persistenceStorageMock.configuration)
    }
    
    // MARK: - Base Migrations
    func testPerformOneTestBaseMigrationFromSetUp() {
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 0)
        migrationManager.migrate()
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 1)
    }
    
    func testPerformTwoTestBaseMigrations() {
        let testMigrations: [MigrationProtocol] = [
            TestBaseMigration_1(),
            TestBaseMigration_2()
        ]
        
        migrationManager = MigrationManager(persistenceStorage: persistenceStorageMock,
                                            migrations: testMigrations, sdkVersionCode: 2)
        
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 0)
        migrationManager.migrate()
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 2)
    }
    
    func testPerformThreeTestBaseMigrationsWithOneIsNeededEqualFalse() {
        let testMigrations: [MigrationProtocol] = [
            TestBaseMigration_1(),
            TestBaseMigration_2(),
            TestBaseMigration_3_IsNeeded_False() // IsNeeded == false -> No auto increment in BaseMigration
        ]
        
        migrationManager = MigrationManager(
            persistenceStorage: persistenceStorageMock,
            migrations: testMigrations,
            sdkVersionCode: 2
        )
        
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 0)
        migrationManager.migrate()
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 2)
    }
    
    func test_sort_PerformThreeTestMigrationsThatAreDecalredInARandomOrder() {
        let testMigrations: [MigrationProtocol] = [
            TestBaseMigration_2(),
            TestBaseMigration_3_IsNeeded_False(),
            TestBaseMigration_1(),
        ]
        
        migrationManager = MigrationManager(persistenceStorage: persistenceStorageMock,
                                            migrations: testMigrations, sdkVersionCode: 2)
        
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 0)
        migrationManager.migrate()
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 2)
    }
    
    func testPerformTestBaseMigrationsWhenOneThrowError() {
        let testMigrations: [MigrationProtocol] = [
            TestBaseMigration_2(),
            TestBaseMigration_1(),
            TestBaseMigration_4_WithPerfomError(),
        ]
        
        migrationManager = MigrationManager(persistenceStorage: persistenceStorageMock,
                                            migrations: testMigrations, sdkVersionCode: 3)
        
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 0)
        migrationManager.migrate()
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 3)
        XCTAssertNil(persistenceStorageMock.configuration, "Must softReset() persistenceStorage")
    }
    
    // MARK: - Protocol Migrations
    func testPerformOneTestProtocolMigration() {
        let testMigrations: [MigrationProtocol] = [
            TestProtocolMigration_1()
        ]
        
        migrationManager = MigrationManager(persistenceStorage: persistenceStorageMock,
                                            migrations: testMigrations, sdkVersionCode: 0)
        
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 0)
        migrationManager.migrate()
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 0)
    }
    
    func testPerformTwoTestProtocolMigrations() {
        let testMigrations: [MigrationProtocol] = [
            TestProtocolMigration_1(),
            TestProtocolMigration_2(persistenceStorage: persistenceStorageMock) // Used increment sdkVersionCode into `run`
        ]
        
        migrationManager = MigrationManager(persistenceStorage: persistenceStorageMock,
                                            migrations: testMigrations, sdkVersionCode: 1)
        
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 0)
        migrationManager.migrate()
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 1)
    }
    
    func testPerformThreeTestProtocolMigrations() {
        let testMigrations: [MigrationProtocol] = [
            TestProtocolMigration_1(),
            TestProtocolMigration_2(persistenceStorage: persistenceStorageMock), // Used increment sdkVersionCode into `run`
            TestProtocolMigration_3(persistenceStorage: persistenceStorageMock) // Throw error into `run`
        ]
        
        let expectedSdkVersionCodeAfterMigrations = 2
        
        persistenceStorageMock.deviceUUID = "00000000-0000-0000-0000-000000000000"
        persistenceStorageMock.installationDate = Date()
        
        migrationManager = MigrationManager(persistenceStorage: persistenceStorageMock,
                                            migrations: testMigrations, sdkVersionCode: expectedSdkVersionCodeAfterMigrations)
        
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 0)
        migrationManager.migrate()
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == expectedSdkVersionCodeAfterMigrations)
        XCTAssertNil(persistenceStorageMock.configuration, "Must softReset() persistenceStorage")
    }
    
    // MARK: - Mixed Migrations
    func testPerformMixedTestMigrations() {
        let testMigrations: [MigrationProtocol] = [
            TestBaseMigration_1(), // Auto Increment sdkVersionCode
            TestBaseMigration_2(), // Auto Increment sdkVersionCode
            TestProtocolMigration_1(),
            TestProtocolMigration_2(persistenceStorage: persistenceStorageMock), // Used increment sdkVersionCode into `run`
        ]
        
        let expectedSdkVersionCodeAfterMigrations = 3
        
        migrationManager = MigrationManager(persistenceStorage: persistenceStorageMock,
                                            migrations: testMigrations, sdkVersionCode: expectedSdkVersionCodeAfterMigrations)
        
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == 0)
        migrationManager.migrate()
        XCTAssertTrue(persistenceStorageMock.versionCodeForMigration == expectedSdkVersionCodeAfterMigrations)
        XCTAssertNotNil(persistenceStorageMock.configuration)
    }
}

// MARK: - Fileprivate Test Base Migrations


fileprivate final class TestBaseMigration_1: BaseMigration {
    override var description: String {
        "TestBaseMigration number 1"
    }
    
    override var isNeeded: Bool {
        true
    }
    
    override var version: Int {
        1
    }
    
    override func performMigration() throws {
        // Do some code
    }
}

fileprivate final class TestBaseMigration_2: BaseMigration {
    override var description: String {
        "TestBaseMigration number 2"
    }
    
    override var isNeeded: Bool {
        true
    }
    
    override var version: Int {
        2
    }
    
    override func performMigration() throws {
        // Do some code
    }
}

fileprivate final class TestBaseMigration_3_IsNeeded_False: BaseMigration {
    override var description: String {
        "TestBaseMigration number 3. isNeeded == false"
    }
    
    override var isNeeded: Bool {
        false
    }
    
    override var version: Int {
        3
    }
    
    override func performMigration() throws {
        // Do some code
    }
}

fileprivate final class TestBaseMigration_4_WithPerfomError: BaseMigration {
    override var description: String {
        "TestBaseMigration number 4. perfromMigration throw error"
    }
    
    override var isNeeded: Bool {
        true
    }
    
    override var version: Int {
        4
    }
    
    override func performMigration() throws {
        // Do some code
        throw NSError(domain: "com.sdk.migration", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid version for migration"])
    }
}

// MARK: - Fileprivate Test Protocol Migrations

fileprivate final class TestProtocolMigration_1: MigrationProtocol {
    var description: String {
        "TestProtocolMigration number 1 with migration version 5"
    }
    
    var isNeeded: Bool {
        return true
    }
    
    var version: Int {
        return 5
    }
    
    func run() throws {
        // Do some code
    }
}

fileprivate final class TestProtocolMigration_2: MigrationProtocol {
    
    private var persistenceStorage: PersistenceStorage
    
    var description: String {
        "TestProtocolMigration number 2 with migration version 6"
    }
    
    var isNeeded: Bool {
        return true
    }
    
    var version: Int {
        return 6
    }
    
    func run() throws {
        // Do some code
        let versionCodeForMigration = persistenceStorage.versionCodeForMigration!
        persistenceStorage.versionCodeForMigration = versionCodeForMigration + 1
    }
    
    init(persistenceStorage: PersistenceStorage) {
        self.persistenceStorage = persistenceStorage
    }
}

fileprivate final class TestProtocolMigration_3: MigrationProtocol {
    
    private var persistenceStorage: PersistenceStorage
    
    var description: String {
        "TestProtocolMigration number 3 with migration version 7"
    }
    
    var isNeeded: Bool {
        return true
    }
    
    var version: Int {
        return 7
    }
    
    func run() throws {
        // Do some code
        throw NSError(domain: "com.sdk.migration", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid version for migration"])
        let versionCodeForMigration = persistenceStorage.versionCodeForMigration!
        persistenceStorage.versionCodeForMigration = versionCodeForMigration + 1
    }
    
    init(persistenceStorage: PersistenceStorage) {
        self.persistenceStorage = persistenceStorage
    }
}
