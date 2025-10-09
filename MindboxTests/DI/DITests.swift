//
//  DITests.swift
//  MindboxTests
//
//  Created by vailence on 11.07.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

class TestModeRegistrationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MBInject.mode = .test
    }

    func testUUIDDebugServiceIsRegistered() {
        let service: UUIDDebugService? = DI.inject(UUIDDebugService.self)
        XCTAssertNotNil(service)
        XCTAssert(service is MockUUIDDebugService)
    }

    func testUNAuthorizationStatusProviderIsRegistered() {
        let provider: UNAuthorizationStatusProviding? = DI.inject(UNAuthorizationStatusProviding.self)
        XCTAssertNotNil(provider)
        XCTAssert(provider is MockUNAuthorizationStatusProvider)
    }

    func testSDKVersionValidatorIsRegistered() {
        let validator: SDKVersionValidator? = DI.inject(SDKVersionValidator.self)
        XCTAssertNotNil(validator)
    }

    func testPersistenceStorageIsRegistered() {
        let storage: PersistenceStorage? = DI.inject(PersistenceStorage.self)
        XCTAssertNotNil(storage)
        XCTAssert(storage is MockPersistenceStorage)
    }

    func testDatabaseRepositoryIsRegistered() {
        let repository: DatabaseRepositoryProtocol? = DI.inject(DatabaseRepositoryProtocol.self)
        XCTAssertNotNil(repository)
        XCTAssert(repository is MockDatabaseRepository)
    }

    func testImageDownloadServiceIsRegistered() {
        let service: ImageDownloadServiceProtocol? = DI.inject(ImageDownloadServiceProtocol.self)
        XCTAssertNotNil(service)
        XCTAssert(service is MockImageDownloadService)
    }

    func testNetworkFetcherIsRegistered() {
        let fetcher: NetworkFetcher? = DI.inject(NetworkFetcher.self)
        XCTAssertNotNil(fetcher)
        XCTAssert(fetcher is MockNetworkFetcher)
    }

    func testInAppConfigurationDataFacadeIsRegistered() {
        let facade: InAppConfigurationDataFacadeProtocol? = DI.inject(InAppConfigurationDataFacadeProtocol.self)
        XCTAssertNotNil(facade)
        XCTAssert(facade is MockInAppConfigurationDataFacade)
    }

    func testSessionManagerIsRegistered() {
        let manager: SessionManager? = DI.inject(SessionManager.self)
        XCTAssertNotNil(manager)
        XCTAssert(manager is MockSessionManager)
    }

    func testSDKLogsManagerIsRegistered() {
        let manager: SDKLogsManagerProtocol? = DI.inject(SDKLogsManagerProtocol.self)
        XCTAssertNotNil(manager)
        XCTAssert(manager is SDKLogsManager)
    }

    func testInAppCoreManagerIsRegistered() {
        let manager: InAppCoreManagerProtocol? = DI.inject(InAppCoreManagerProtocol.self)
        XCTAssertNotNil(manager)
        XCTAssert(manager is InAppCoreManagerMock)
    }

    // Добавьте тесты для всех остальных классов
}
