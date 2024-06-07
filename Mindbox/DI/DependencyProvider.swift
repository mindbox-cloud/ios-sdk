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
    let persistenceStorage: PersistenceStorage = container.inject(PersistenceStorage.self)
    
    let databaseLoader: DataBaseLoader
    let databaseRepository: MBDatabaseRepository
    let guaranteedDeliveryManager: GuaranteedDeliveryManager
    let authorizationStatusProvider: UNAuthorizationStatusProviding
    let sessionManager: SessionManager
    let instanceFactory: InstanceFactory
    let inAppTargetingChecker: InAppTargetingChecker
    let inAppMessagesManager: InAppCoreManagerProtocol
    let uuidDebugService: UUIDDebugService
    var inappMessageEventSender: InappMessageEventSender
    let sdkVersionValidator: SDKVersionValidator
    let geoService: GeoServiceProtocol
    let segmentationSevice: SegmentationServiceProtocol
    var imageDownloadService: ImageDownloadServiceProtocol
    var urlExtractorService: VariantImageUrlExtractorService
    var inappFilterService: InappFilterProtocol
    var pushValidator: MindboxPushValidator
    var inAppConfigurationDataFacade: InAppConfigurationDataFacadeProtocol
    var userVisitManager: UserVisitManagerProtocol
    var ttlValidationService: TTLValidationProtocol
    var frequencyValidator: InappFrequencyValidator

    init() throws {
//        persistenceStorage = MBPersistenceStorage()
//        persistenceStorage = container.inject(PersistenceStorage.self)
//        persistenceStorage.migrateShownInAppsIds()
        inAppTargetingChecker = InAppTargetingChecker()
        databaseLoader = try DataBaseLoader()
        let persistentContainer = try databaseLoader.loadPersistentContainer()
        databaseRepository = try MBDatabaseRepository(persistentContainer: persistentContainer)
        instanceFactory = MBInstanceFactory(
            databaseRepository: databaseRepository
        )
        guaranteedDeliveryManager = GuaranteedDeliveryManager(
            databaseRepository: databaseRepository,
            eventRepository: instanceFactory.makeEventRepository()
        )
        authorizationStatusProvider = UNAuthorizationStatusProvider()
        sessionManager = MBSessionManager(trackVisitManager: instanceFactory.makeTrackVisitManager())
        let logsManager = SDKLogsManager(eventRepository: instanceFactory.makeEventRepository())

        sdkVersionValidator = SDKVersionValidator(sdkVersionNumeric: Constants.Versions.sdkVersionNumeric)
        geoService = GeoService(fetcher: instanceFactory.makeNetworkFetcher(),
                                targetingChecker: inAppTargetingChecker)
        segmentationSevice = SegmentationService(customerSegmentsAPI: .live,
                                                 targetingChecker: inAppTargetingChecker)
        let imageDownloader = URLSessionImageDownloader()
        imageDownloadService = ImageDownloadService(imageDownloader: imageDownloader)
//        abTestDeviceMixer = ABTestDeviceMixer()
        let tracker = InAppMessagesTracker(databaseRepository: databaseRepository)
        let displayUseCase = PresentationDisplayUseCase(tracker: tracker)
        let actionUseCaseFactory = ActionUseCaseFactory(tracker: tracker)
        let actionHandler = InAppActionHandler(actionUseCaseFactory: actionUseCaseFactory)
        let presentationManager = InAppPresentationManager(actionHandler: actionHandler,
                                                           displayUseCase: displayUseCase)
        urlExtractorService = VariantImageUrlExtractorService()
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

        frequencyValidator = InappFrequencyValidator()
        inappFilterService = InappsFilterService(variantsFilter: variantsFilterService,
                                                 sdkVersionValidator: sdkVersionValidator, 
                                                 frequencyValidator: frequencyValidator)
        
        ttlValidationService = TTLValidationService()
        inAppConfigurationDataFacade = InAppConfigurationDataFacade(geoService: geoService,
                                                                    segmentationService: segmentationSevice,
                                                                    targetingChecker: inAppTargetingChecker,
                                                                    imageService: imageDownloadService, 
                                                                    tracker: tracker)
        
        inAppMessagesManager = InAppCoreManager(
            configManager: InAppConfigurationManager(
                inAppConfigAPI: InAppConfigurationAPI(),
                inAppConfigRepository: InAppConfigurationRepository(),
                inAppConfigurationMapper: InAppConfigutationMapper(inappFilterService: inappFilterService,
                                                                   targetingChecker: inAppTargetingChecker,
                                                                   urlExtractorService: urlExtractorService,
                                                                   dataFacade: inAppConfigurationDataFacade),
                logsManager: logsManager,
                ttlValidationService: ttlValidationService),
            presentationManager: presentationManager
        )
        inappMessageEventSender = InappMessageEventSender(inAppMessagesManager: inAppMessagesManager)

        uuidDebugService = PasteboardUUIDDebugService(
            notificationCenter: NotificationCenter.default,
            currentDateProvider: { return Date() },
            pasteboard: UIPasteboard.general
        )
        
        pushValidator = MindboxPushValidator()
        userVisitManager = UserVisitManager()
    }
}

class MBInstanceFactory: InstanceFactory {
    private let persistenceStorage: PersistenceStorage
    private let utilitiesFetcher: UtilitiesFetcher
    private let databaseRepository: MBDatabaseRepository

    init(
        persistenceStorage: PersistenceStorage = container.inject(PersistenceStorage.self),
        utilitiesFetcher: UtilitiesFetcher = container.inject(UtilitiesFetcher.self),
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
