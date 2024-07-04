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
    var geoService: GeoServiceProtocol
    var inappFilterService: InappFilterProtocol
    var inAppConfigurationDataFacade: InAppConfigurationDataFacadeProtocol
    
    init() throws {
        utilitiesFetcher = MBUtilitiesFetcher()
        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        let databaseLoader = DI.injectOrFail(DataBaseLoader.self)
        let persistentContainer = try databaseLoader.loadPersistentContainer()
        databaseRepository = try MockDatabaseRepository(persistentContainer: persistentContainer)
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
        geoService = GeoService(fetcher: instanceFactory.makeNetworkFetcher(),
                                targetingChecker: inAppTargetingChecker)
        let segmentationSevice = DI.injectOrFail(SegmentationServiceProtocol.self)
        let imageDownloadService = DI.injectOrFail(ImageDownloadServiceProtocol.self)
        let tracker = InAppMessagesTracker(databaseRepository: databaseRepository)
        inAppConfigurationDataFacade = InAppConfigurationDataFacade(geoService: geoService,
                                                                    segmentationService: segmentationSevice,
                                                                    targetingChecker: inAppTargetingChecker,
                                                                    imageService: imageDownloadService,
                                                                    tracker: tracker)

        let actionFilter = LayerActionFilterService()
        let sourceFilter = LayersSourceFilterService()
        let layersFilterService = LayersFilterService(actionFilter: actionFilter, sourceFilter: sourceFilter)
        let sizeFilter = ElementSizeFilterService()
        let colorFilter = ElementsColorFilterService()
        let positionFilter = ElementsPositionFilterService()
        let elementsFilterService = ElementsFilterService(sizeFilter: sizeFilter, positionFilter: positionFilter, colorFilter: colorFilter)
        let contentPositionFilterService = ContentPositionFilterService()
        let variantsFilterService = VariantFilterService(layersFilter: layersFilterService,
                                                         elementsFilter: elementsFilterService,
                                                         contentPositionFilter: contentPositionFilterService)
        inappFilterService = InappsFilterService(persistenceStorage: persistenceStorage,
                                                 variantsFilter: variantsFilterService,
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

