//
//  InjectionMocks.swift
//  MindboxTests
//
//  Created by vailence on 21.06.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
@testable import Mindbox

// swiftlint:disable force_try

extension MBContainer {
    func registerMocks() -> Self {
        register(UUIDDebugService.self) {
            MockUUIDDebugService()
        }

        register(UNAuthorizationStatusProviding.self, scope: .transient) {
            MockUNAuthorizationStatusProvider(status: .authorized)
        }

        register(SDKVersionValidator.self) {
            SDKVersionValidator(sdkVersionNumeric: Constants.Versions.sdkVersionNumeric)
        }

        register(PersistenceStorage.self) {
            MockPersistenceStorage()
        }

        register(DatabaseRepository.self) {
            return try! MockDatabaseRepository(inMemory: true)
        }

        register(ImageDownloadServiceProtocol.self, scope: .container) {
            MockImageDownloadService()
        }

        register(NetworkFetcher.self) {
            MockNetworkFetcher()
        }

        register(InAppConfigurationDataFacadeProtocol.self) {
            let segmentationService = DI.injectOrFail(SegmentationServiceProtocol.self)
            let targetingChecker = DI.injectOrFail(InAppTargetingCheckerProtocol.self)
            let imageService = DI.injectOrFail(ImageDownloadServiceProtocol.self)
            let tracker = DI.injectOrFail(InAppMessagesTracker.self)
            return MockInAppConfigurationDataFacade(segmentationService: segmentationService,
                                                    targetingChecker: targetingChecker,
                                                    imageService: imageService,
                                                    tracker: tracker)
        }

        register(SessionManager.self) {
            MockSessionManager()
        }

        register(EventRepositoryMock.self) {
            EventRepositoryMock()
        }

        register(SDKLogsManagerProtocol.self) {
            let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
            let eventRepository = DI.injectOrFail(EventRepositoryMock.self)
            return SDKLogsManager(persistenceStorage: persistenceStorage, eventRepository: eventRepository)
        }

        register(InAppCoreManagerProtocol.self) {
            InAppCoreManagerMock()
        }

        return self
    }
}
