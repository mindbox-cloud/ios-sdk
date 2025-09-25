//
//  DIMainModuleReplaceableTests.swift
//  MindboxTests
//
//  Created by vailence on 11.07.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

class DIMainModuleReplaceableTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MBInject.mode = .standard
    }

    func testUUIDDebugServiceIsRegistered() {
        let service: UUIDDebugService? = DI.inject(UUIDDebugService.self)
        XCTAssertNotNil(service)
        XCTAssert(service is PasteboardUUIDDebugService)
    }

    func testUNAuthorizationStatusProviderIsRegistered() {
        let provider: UNAuthorizationStatusProviding? = DI.inject(UNAuthorizationStatusProviding.self)
        XCTAssertNotNil(provider)
        XCTAssert(provider is UNAuthorizationStatusProvider)
    }

    func testSDKVersionValidatorIsRegistered() {
        let validator: SDKVersionValidator? = DI.inject(SDKVersionValidator.self)
        XCTAssertNotNil(validator)
    }

    func testPersistenceStorageIsRegistered() {
        let storage: PersistenceStorage? = DI.inject(PersistenceStorage.self)
        XCTAssertNotNil(storage)
        XCTAssert(storage is MBPersistenceStorage)
    }

    func testDatabaseRepositoryIsRegistered() {
        let repository: DatabaseRepository? = DI.inject(DatabaseRepository.self)
        XCTAssertNotNil(repository)
    }

    func testImageDownloadServiceIsRegistered() {
        let service: ImageDownloadServiceProtocol? = DI.inject(ImageDownloadServiceProtocol.self)
        XCTAssertNotNil(service)
        XCTAssert(service is ImageDownloadService)
    }

    func testNetworkFetcherIsRegistered() {
        let fetcher: NetworkFetcher? = DI.inject(NetworkFetcher.self)
        XCTAssertNotNil(fetcher)
        XCTAssert(fetcher is MBNetworkFetcher)
    }

    func testInAppConfigurationDataFacadeIsRegistered() {
        let facade: InAppConfigurationDataFacadeProtocol? = DI.inject(InAppConfigurationDataFacadeProtocol.self)
        XCTAssertNotNil(facade)
        XCTAssert(facade is InAppConfigurationDataFacade)
    }

    func testSessionManagerIsRegistered() {
        let manager: SessionManager? = DI.inject(SessionManager.self)
        XCTAssertNotNil(manager)
        XCTAssert(manager is MBSessionManager)
    }

    func testSDKLogsManagerIsRegistered() {
        let manager: SDKLogsManagerProtocol? = DI.inject(SDKLogsManagerProtocol.self)
        XCTAssertNotNil(manager)
        XCTAssert(manager is SDKLogsManager)
    }

    func testInAppCoreManagerIsRegistered() {
        let manager: InAppCoreManagerProtocol? = DI.inject(InAppCoreManagerProtocol.self)
        XCTAssertNotNil(manager)
        XCTAssert(manager is InAppCoreManager)
    }
}
