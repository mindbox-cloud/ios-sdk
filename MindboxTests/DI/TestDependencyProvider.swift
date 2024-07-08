//
//  DITest.swift
//  MindboxTests
//
//  Created by Mikhail Barilov on 28.01.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//


import XCTest
@testable import Mindbox

final class TestDependencyProvider: DependencyContainer {
    let inAppMessagesManager: InAppCoreManagerProtocol
    let utilitiesFetcher: UtilitiesFetcher
    let databaseRepository: MBDatabaseRepository
    let guaranteedDeliveryManager: GuaranteedDeliveryManager
    let sessionManager: SessionManager
    let instanceFactory: InstanceFactory
    var inappMessageEventSender: InappMessageEventSender
    var inappFilterService: InappFilterProtocol
    var inAppConfigurationDataFacade: InAppConfigurationDataFacadeProtocol
    
    init() throws {
        utilitiesFetcher = MBUtilitiesFetcher()
        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        databaseRepository = DI.injectOrFail(MBDatabaseRepository.self)
        instanceFactory = MockInstanceFactory(
            persistenceStorage: persistenceStorage,
            utilitiesFetcher: utilitiesFetcher,
            databaseRepository: databaseRepository
        )
        guaranteedDeliveryManager = GuaranteedDeliveryManager(
            persistenceStorage: persistenceStorage,
            databaseRepository: databaseRepository,
            eventRepository: instanceFactory.makeEventRepository()
        )
        sessionManager = MockSessionManager()
        let inAppTargetingChecker = DI.injectOrFail(InAppTargetingCheckerProtocol.self)
        inAppMessagesManager = InAppCoreManagerMock()
        inappMessageEventSender = InappMessageEventSender(inAppMessagesManager: inAppMessagesManager)
        let segmentationSevice = DI.injectOrFail(SegmentationServiceProtocol.self)
        let imageDownloadService = DI.injectOrFail(ImageDownloadServiceProtocol.self)
        let tracker = InAppMessagesTracker(databaseRepository: databaseRepository)
        inAppConfigurationDataFacade = InAppConfigurationDataFacade(segmentationService: segmentationSevice,
                                                                    targetingChecker: inAppTargetingChecker,
                                                                    imageService: imageDownloadService,
                                                                    tracker: tracker)
        
        inappFilterService = InappsFilterService(persistenceStorage: persistenceStorage,
                                                 variantsFilter: DI.injectOrFail(VariantFilterProtocol.self),
                                                 sdkVersionValidator: DI.injectOrFail(SDKVersionValidator.self))
    }
}

class MockInstanceFactory: InstanceFactory {
    
    private let persistenceStorage: PersistenceStorage
    private let utilitiesFetcher: UtilitiesFetcher
    private let databaseRepository: MBDatabaseRepository
    
    var isFailureNetworkFetcher: Bool = false

    init(persistenceStorage: PersistenceStorage, utilitiesFetcher: UtilitiesFetcher, databaseRepository: MBDatabaseRepository) {
        self.persistenceStorage = persistenceStorage
        self.utilitiesFetcher = utilitiesFetcher
        self.databaseRepository = databaseRepository
    }

    func makeNetworkFetcher() -> NetworkFetcher {
        return isFailureNetworkFetcher ? MockFailureNetworkFetcher() : MockNetworkFetcher()
    }

    func makeEventRepository() -> EventRepository {
        return MBEventRepository(
            fetcher: makeNetworkFetcher(),
            persistenceStorage: persistenceStorage
        )
    }
    
    func makeTrackVisitManager() -> TrackVisitManager {
        return TrackVisitManager(databaseRepository: databaseRepository)
    }
}

