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

    var inAppTargetingChecker: InAppTargetingChecker
    let inAppMessagesManager: InAppCoreManagerProtocol
    let utilitiesFetcher: UtilitiesFetcher
    let persistenceStorage: PersistenceStorage
    let databaseLoader: DataBaseLoader
    let databaseRepository: MBDatabaseRepository
    let guaranteedDeliveryManager: GuaranteedDeliveryManager
    let authorizationStatusProvider: UNAuthorizationStatusProviding
    let sessionManager: SessionManager
    let instanceFactory: InstanceFactory
    let uuidDebugService: UUIDDebugService
    var inappMessageEventSender: InappMessageEventSender
    let sdkVersionValidator: SDKVersionValidator
    var geoService: GeoServiceProtocol
    var segmentationSevice: SegmentationServiceProtocol
    var imageDownloadService: ImageDownloadServiceProtocol
    var abTestDeviceMixer: ABTestDeviceMixer
    var urlExtractorService: VariantImageUrlExtractorService
    var inappFilterService: InappFilterProtocol
    var pushValidator: MindboxPushValidator
    var inAppConfigurationDataFacade: InAppConfigurationDataFacadeProtocol
    var pushPermissionFilterService: InappFilterByPushPermission
    var userVisitManager: UserVisitManager
    
    init() throws {
        utilitiesFetcher = MBUtilitiesFetcher()
        persistenceStorage = MockPersistenceStorage()
        databaseLoader = try DataBaseLoader()
        inAppTargetingChecker = InAppTargetingChecker()
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
        authorizationStatusProvider = MockUNAuthorizationStatusProvider(status: .authorized)
        sessionManager = MockSessionManager()
        inAppTargetingChecker = InAppTargetingChecker()
        inAppMessagesManager = InAppCoreManagerMock()
        uuidDebugService = MockUUIDDebugService()
        inappMessageEventSender = InappMessageEventSender(inAppMessagesManager: inAppMessagesManager)
        sdkVersionValidator = SDKVersionValidator(sdkVersionNumeric: 8)
        geoService = GeoService(fetcher: instanceFactory.makeNetworkFetcher(),
                                targetingChecker: inAppTargetingChecker)
        segmentationSevice = SegmentationService(customerSegmentsAPI: .live,
                                                 targetingChecker: inAppTargetingChecker)
        imageDownloadService = MockImageDownloadService()
        abTestDeviceMixer = ABTestDeviceMixer()
        urlExtractorService = VariantImageUrlExtractorService()
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
        inappFilterService = InappsFilterService(variantsFilter: variantsFilterService)
        pushValidator = MindboxPushValidator()
        userVisitManager = UserVisitManager(persistenceStorage: persistenceStorage, sessionManager: sessionManager)
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

