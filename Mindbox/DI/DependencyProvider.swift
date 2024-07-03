//
//  DIManager.swift
//  Mindbox
//
//  Created by Mikhail Barilov on 13.01.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import CoreData
import Foundation
import UIKit

final class DependencyProvider: DependencyContainer {
    let utilitiesFetcher: UtilitiesFetcher
    let databaseRepository: MBDatabaseRepository
    let guaranteedDeliveryManager: GuaranteedDeliveryManager
    let sessionManager: SessionManager
    let instanceFactory: InstanceFactory
    let inAppTargetingChecker: InAppTargetingChecker
    let inAppMessagesManager: InAppCoreManagerProtocol
    var inappMessageEventSender: InappMessageEventSender
    let geoService: GeoServiceProtocol
    let segmentationSevice: SegmentationServiceProtocol
    var inappFilterService: InappFilterProtocol
    var inAppConfigurationDataFacade: InAppConfigurationDataFacadeProtocol

    init() throws {
        utilitiesFetcher = MBUtilitiesFetcher()
        
        let persistenceStorage = DI.injectOrFail(PersistenceStorage.self)
        persistenceStorage.migrateShownInAppsIds()
        inAppTargetingChecker = InAppTargetingChecker(persistenceStorage: persistenceStorage)
        let databaseLoader = DI.injectOrFail(DataBaseLoader.self)
        let persistentContainer = try databaseLoader.loadPersistentContainer()
        databaseRepository = try MBDatabaseRepository(persistentContainer: persistentContainer)
        instanceFactory = MBInstanceFactory(
            persistenceStorage: persistenceStorage,
            utilitiesFetcher: utilitiesFetcher,
            databaseRepository: databaseRepository
        )
        guaranteedDeliveryManager = GuaranteedDeliveryManager(
            persistenceStorage: persistenceStorage,
            databaseRepository: databaseRepository,
            eventRepository: instanceFactory.makeEventRepository()
        )
        sessionManager = MBSessionManager(trackVisitManager: instanceFactory.makeTrackVisitManager())
        let logsManager = SDKLogsManager(persistenceStorage: persistenceStorage, eventRepository: instanceFactory.makeEventRepository())

        geoService = GeoService(fetcher: instanceFactory.makeNetworkFetcher(),
                                targetingChecker: inAppTargetingChecker)
        segmentationSevice = SegmentationService(customerSegmentsAPI: .live,
                                                 targetingChecker: inAppTargetingChecker)
        let imageDownloadService = DI.injectOrFail(ImageDownloadServiceProtocol.self)
        let tracker = InAppMessagesTracker(databaseRepository: databaseRepository)
        let displayUseCase = PresentationDisplayUseCase(tracker: tracker)
        let actionUseCaseFactory = ActionUseCaseFactory(tracker: tracker)
        let actionHandler = InAppActionHandler(actionUseCaseFactory: actionUseCaseFactory)
        let presentationManager = InAppPresentationManager(actionHandler: actionHandler,
                                                           displayUseCase: displayUseCase)
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
        
        inAppConfigurationDataFacade = InAppConfigurationDataFacade(geoService: geoService,
                                                                    segmentationService: segmentationSevice,
                                                                    targetingChecker: inAppTargetingChecker,
                                                                    imageService: imageDownloadService, 
                                                                    tracker: tracker)
        
        inAppMessagesManager = InAppCoreManager(
            configManager: InAppConfigurationManager(
                inAppConfigAPI: InAppConfigurationAPI(persistenceStorage: persistenceStorage),
                inAppConfigRepository: InAppConfigurationRepository(),
                inAppConfigurationMapper: InAppConfigutationMapper(inappFilterService: inappFilterService,
                                                                   targetingChecker: inAppTargetingChecker,
                                                                   dataFacade: inAppConfigurationDataFacade),
                logsManager: logsManager,
            persistenceStorage: persistenceStorage),
            presentationManager: presentationManager,
            persistenceStorage: persistenceStorage
        )
        inappMessageEventSender = InappMessageEventSender(inAppMessagesManager: inAppMessagesManager)        
    }
}

class MBInstanceFactory: InstanceFactory {
    private let persistenceStorage: PersistenceStorage
    private let utilitiesFetcher: UtilitiesFetcher
    private let databaseRepository: MBDatabaseRepository

    init(
        persistenceStorage: PersistenceStorage,
        utilitiesFetcher: UtilitiesFetcher,
        databaseRepository: MBDatabaseRepository
    ) {
        self.persistenceStorage = persistenceStorage
        self.utilitiesFetcher = utilitiesFetcher
        self.databaseRepository = databaseRepository
    }

    func makeNetworkFetcher() -> NetworkFetcher {
        return MBNetworkFetcher(
            utilitiesFetcher: utilitiesFetcher,
            persistenceStorage: persistenceStorage
        )
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
